#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

repo_root="$(enter_repo_root)"

# ── shared paths ──────────────────────────────────────────────
key_dir="$repo_root/.keys"
secrets_key_dir="$repo_root/secrets/keys"
host_key_dir="$secrets_key_dir/hosts"
main_key="$key_dir/main.agekey"
main_pub="$secrets_key_dir/main.age.pub"
recovery_key="$key_dir/recovery.agekey"
recovery_pub="$secrets_key_dir/recovery.age.pub"

# ── helpers ───────────────────────────────────────────────────
require_main_key() {
  if [ ! -f "$main_key" ]; then
    echo "error: missing $main_key" >&2
    echo "hint: import your existing main key, or run: nix/scripts/admin/sops.sh init --create" >&2
    exit 1
  fi
}

require_main_pub() {
  if [ ! -f "$main_pub" ]; then
    echo "error: missing $main_pub; run: nix/scripts/admin/sops.sh init" >&2
    exit 1
  fi
  if [ -z "$(tr -d '\n' < "$main_pub")" ]; then
    echo "error: empty public key file: $main_pub" >&2
    exit 1
  fi
}

trim_line() {
  tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

collect_age_recipients() {
  local item host_file host_rec
  local -a recipients

  if [ -f "$main_pub" ]; then
    item="$(trim_line < "$main_pub")"
    [ -n "$item" ] && recipients+=("$item")
  fi

  if [ -f "$recovery_pub" ]; then
    item="$(trim_line < "$recovery_pub")"
    [ -n "$item" ] && recipients+=("$item")
  fi

  if [ -d "$host_key_dir" ]; then
    while IFS= read -r host_file; do
      if ! host_rec="$(run_ssh_to_age < "$host_file" 2>/dev/null | trim_line)"; then
        echo "error: invalid host recipient file: $host_file" >&2
        return 1
      fi
      if [ -z "$host_rec" ]; then
        echo "error: empty host recipient derived from: $host_file" >&2
        return 1
      fi
      recipients+=("$host_rec")
    done < <(find "$host_key_dir" -maxdepth 1 -type f -name '*.pub' | sort)
  fi

  if [ "${#recipients[@]}" -eq 0 ]; then
    return 1
  fi

  printf '%s\n' "${recipients[@]}" | awk 'NF && !seen[$0]++'
}

collect_age_recipients_csv() {
  collect_age_recipients | paste -sd, -
}

encrypt_yaml_to_target() {
  local target="$1"
  local recipients_csv="$2"
  local tmp

  tmp="$(mktemp)"
  cat > "$tmp"
  mkdir -p "$(dirname "$target")"
  run_sops_encrypt_yaml "$recipients_csv" "$target" < "$tmp"
  rm -f "$tmp"
}

# ── subcommands ───────────────────────────────────────────────

cmd_init() {
  local mode="default"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --create) mode="create"; shift ;;
      --rotate) mode="rotate"; shift ;;
      *) echo "error: unknown argument: $1" >&2; exit 2 ;;
    esac
  done

  mkdir -p "$key_dir" "$secrets_key_dir"

  case "$mode" in
    default)
      if [ ! -f "$main_key" ]; then
        echo "error: missing $main_key" >&2
        echo "hint: import your existing main key first, then rerun." >&2
        echo "      use --create only for the very first bootstrap." >&2
        exit 1
      fi
      ;;
    create)
      if [ ! -f "$main_key" ]; then
        run_age_keygen -o "$main_key" >/dev/null
        echo "created new main key: $main_key"
      fi
      ;;
    rotate)
      run_age_keygen -o "$main_key" >/dev/null
      echo "rotated main key: $main_key"
      echo "warning: run 'nix/scripts/admin/sops.sh rekey' before next deployment."
      ;;
  esac

  chmod 0400 "$main_key"
  run_age_keygen -y "$main_key" > "$main_pub"

  echo "sops key ready:"
  echo "- private: $main_key"
  echo "- public : $main_pub"
}

cmd_password_set() {
  if [ $# -ne 1 ]; then
    echo "usage: sops.sh password-set '<sha512-hash>'" >&2
    exit 2
  fi

  local password_hash="$1"
  local user_secret="$repo_root/secrets/passwords/user-password.yaml"
  local root_secret="$repo_root/secrets/passwords/root-password.yaml"
  local recipients_csv

  require_main_pub
  recipients_csv="$(collect_age_recipients_csv)"

  encrypt_yaml_to_target "$user_secret" "$recipients_csv" <<EOF_HASH
value: "$password_hash"
EOF_HASH

  encrypt_yaml_to_target "$root_secret" "$recipients_csv" <<EOF_HASH
value: "$password_hash"
EOF_HASH

  echo "updated sops password secrets:"
  echo "- $user_secret"
  echo "- $root_secret"
}

cmd_ssh_key_set() {
  local private_src="$repo_root/.keys/github_id_ed25519"
  local public_src="$repo_root/.keys/github_id_ed25519.pub"
  local private_secret="$repo_root/secrets/ssh/github_id_ed25519.yaml"
  local public_secret="$repo_root/secrets/ssh/github_id_ed25519_pub.yaml"
  local recipients_csv

  if [ ! -f "$private_src" ]; then
    echo "error: missing $private_src" >&2
    echo "hint: place your SSH private key at .keys/github_id_ed25519 first" >&2
    exit 1
  fi

  if [ ! -f "$public_src" ]; then
    run_ssh_keygen -y -f "$private_src" > "$public_src"
  fi

  chmod 0600 "$private_src"
  chmod 0644 "$public_src"

  require_main_pub
  recipients_csv="$(collect_age_recipients_csv)"

  {
    echo "value: |"
    sed 's/^/  /' "$private_src"
  } | encrypt_yaml_to_target "$private_secret" "$recipients_csv"

  {
    echo "value: |"
    sed 's/^/  /' "$public_src"
  } | encrypt_yaml_to_target "$public_secret" "$recipients_csv"

  echo "updated sops ssh key secrets:"
  echo "- $private_secret"
  echo "- $public_secret"
}

cmd_recovery_init() {
  local force=0
  if [ "${1:-}" = "--force" ]; then
    force=1
    shift
  fi
  if [ "$#" -ne 0 ]; then
    echo "error: unexpected arguments for recovery-init" >&2
    exit 2
  fi

  mkdir -p "$key_dir" "$secrets_key_dir"

  if [ "$force" -eq 1 ] || [ ! -f "$recovery_key" ]; then
    run_age_keygen -o "$recovery_key" >/dev/null
    echo "recovery identity ready: $recovery_key"
  fi
  chmod 0400 "$recovery_key"
  run_age_keygen -y "$recovery_key" > "$recovery_pub"
  echo "recovery recipient updated: $recovery_pub"
}

cmd_host_add() {
  local host="${1:-}"
  local pub_src="${2:-/etc/ssh/ssh_host_ed25519_key.pub}"

  if [ -z "$host" ]; then
    echo "error: host name is required" >&2
    exit 2
  fi
  if ! is_valid_host_name "$host"; then
    echo "error: invalid host name '$host'" >&2
    exit 2
  fi
  if [ ! -f "$pub_src" ]; then
    echo "error: missing host public key: $pub_src" >&2
    exit 1
  fi

  local first_field second_field
  first_field="$(awk '{print $1}' "$pub_src" | head -n 1)"
  second_field="$(awk '{print $2}' "$pub_src" | head -n 1)"
  if [ "$first_field" != "ssh-ed25519" ] || [ -z "$second_field" ]; then
    echo "error: invalid ssh-ed25519 public key file: $pub_src" >&2
    exit 1
  fi

  mkdir -p "$host_key_dir"
  local target="$host_key_dir/${host}.ssh_host_ed25519.pub"
  cp "$pub_src" "$target"
  chmod 0644 "$target"
  echo "host recipient updated: $target"
}

cmd_recipients() {
  mkdir -p "$host_key_dir"
  echo "recipient files:"
  if [ -f "$main_pub" ]; then
    echo "- secrets/keys/main.age.pub"
  fi
  if [ -f "$recovery_pub" ]; then
    echo "- secrets/keys/recovery.age.pub"
  fi
  find "$host_key_dir" -maxdepth 1 -type f -name '*.pub' -print \
    | sed "s|^$repo_root/|- |" \
    | sort

  echo ""
  echo "resolved age recipients:"
  collect_age_recipients | sed 's/^/- /'
}

cmd_rekey() {
  local recipients_csv file tmp_plain tmp_enc

  require_main_key
  require_main_pub
  recipients_csv="$(collect_age_recipients_csv)"

  export SOPS_AGE_KEY_FILE="$main_key"

  while IFS= read -r file; do
    tmp_plain="$(mktemp)"
    tmp_enc="$(mktemp)"

    run_sops --decrypt "$file" > "$tmp_plain"
    run_sops --encrypt --age "$recipients_csv" --input-type yaml --output-type yaml "$tmp_plain" > "$tmp_enc"
    mv "$tmp_enc" "$file"
    rm -f "$tmp_plain"
    echo "rekeyed: $file"
  done < <(find "$repo_root/secrets" -type f -name '*.yaml' | sort)

  echo "rekey completed."
}

# ── usage ─────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
usage: sops.sh <command> [args]

commands:
  init [--create|--rotate]       Initialize/sync main age key
  password-set <sha512-hash>     Encrypt password hash for user + root
  ssh-key-set                    Encrypt .keys/github_id_ed25519 via sops
  recovery-init [--force]        Create/update recovery key pair
  host-add <host> [pub-path]     Register host SSH public key as recipient
  recipients                     List current recipient key files
  rekey                          Re-encrypt all secrets/*.yaml
EOF
}

# ── dispatch ──────────────────────────────────────────────────
cmd="${1:-}"
if [ -z "$cmd" ]; then
  usage >&2
  exit 2
fi
shift

case "$cmd" in
  init)           cmd_init "$@" ;;
  password-set)   cmd_password_set "$@" ;;
  ssh-key-set)    cmd_ssh_key_set "$@" ;;
  recovery-init)  cmd_recovery_init "$@" ;;
  host-add)       cmd_host_add "$@" ;;
  recipients)     cmd_recipients "$@" ;;
  rekey)          cmd_rekey "$@" ;;
  -h|--help)      usage; exit 0 ;;
  *)
    echo "error: unknown command '$cmd'" >&2
    usage >&2
    exit 2
    ;;
esac
