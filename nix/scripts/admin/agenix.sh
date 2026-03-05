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
    echo "hint: import your existing main key, or run: nix/scripts/admin/agenix.sh init --create" >&2
    exit 1
  fi
}

require_main_pub() {
  if [ ! -f "$main_pub" ]; then
    echo "error: missing $main_pub; run: nix/scripts/admin/agenix.sh init" >&2
    exit 1
  fi
  if [ -z "$(tr -d '\n' < "$main_pub")" ]; then
    echo "error: empty public key file: $main_pub" >&2
    exit 1
  fi
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
      echo "warning: run 'nix/scripts/admin/agenix.sh rekey' before next deployment."
      ;;
  esac

  chmod 0400 "$main_key"
  run_age_keygen -y "$main_key" > "$main_pub"

  echo "agenix key ready:"
  echo "- private: $main_key"
  echo "- public : $main_pub"
}

cmd_password_set() {
  if [ $# -ne 1 ]; then
    echo "usage: agenix.sh password-set '<sha512-hash>'" >&2
    exit 2
  fi

  local password_hash="$1"
  local user_secret_rel="./secrets/passwords/user-password.age"
  local root_secret_rel="./secrets/passwords/root-password.age"
  local user_secret="$repo_root/secrets/passwords/user-password.age"
  local root_secret="$repo_root/secrets/passwords/root-password.age"

  require_main_key
  require_main_pub
  mkdir -p "$(dirname "$user_secret")"

  local tmp
  tmp="$(mktemp)"
  printf '%s\n' "$password_hash" > "$tmp"

  run_agenix_encrypt "$tmp" "$user_secret_rel" "$main_key"
  run_agenix_encrypt "$tmp" "$root_secret_rel" "$main_key"
  rm -f "$tmp"

  echo "updated agenix password secrets:"
  echo "- $user_secret"
  echo "- $root_secret"
}

cmd_ssh_key_set() {
  local private_src="$repo_root/.keys/github_id_ed25519"
  local public_src="$repo_root/.keys/github_id_ed25519.pub"
  local private_secret_rel="./secrets/ssh/github_id_ed25519.age"
  local public_secret_rel="./secrets/ssh/github_id_ed25519.pub.age"
  local private_secret="$repo_root/secrets/ssh/github_id_ed25519.age"
  local public_secret="$repo_root/secrets/ssh/github_id_ed25519.pub.age"

  if [ ! -f "$private_src" ]; then
    echo "error: missing $private_src" >&2
    echo "hint: place your SSH private key at .keys/github_id_ed25519 first" >&2
    exit 1
  fi

  require_main_key

  if [ ! -f "$public_src" ]; then
    run_ssh_keygen -y -f "$private_src" > "$public_src"
  fi

  chmod 0600 "$private_src"
  chmod 0644 "$public_src"
  mkdir -p "$(dirname "$private_secret")"

  run_agenix_encrypt "$private_src" "$private_secret_rel" "$main_key"
  run_agenix_encrypt "$public_src" "$public_secret_rel" "$main_key"

  echo "updated agenix ssh key secrets:"
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
}

cmd_rekey() {
  require_main_key
  if [ ! -f "$repo_root/secrets.nix" ]; then
    echo "error: missing $repo_root/secrets.nix" >&2
    exit 1
  fi

  if [ -f "$recovery_key" ]; then
    run_agenix -r -i "$main_key" -i "$recovery_key"
  else
    run_agenix -r -i "$main_key"
  fi
  echo "rekey completed."
}

# ── usage ─────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
usage: agenix.sh <command> [args]

commands:
  init [--create|--rotate]       Initialize/sync main age key
  password-set <sha512-hash>     Encrypt password hash for user + root
  ssh-key-set                    Encrypt .keys/github_id_ed25519 via agenix
  recovery-init [--force]        Create/update recovery key pair
  host-add <host> [pub-path]     Register host SSH public key as recipient
  recipients                     List current recipient key files
  rekey                          Re-encrypt all secrets/*.age
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
