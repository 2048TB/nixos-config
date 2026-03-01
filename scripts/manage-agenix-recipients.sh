#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"

usage() {
  cat <<'EOF'
usage:
  manage-agenix-recipients.sh <command> [args]

commands:
  init-recovery [--force]
    - create/update .keys/recovery.agekey and secrets/keys/recovery.age.pub

  add-host <host> [ssh-host-pub-path]
    - register host ssh public key as recipient
    - default ssh-host-pub-path: /etc/ssh/ssh_host_ed25519_key.pub

  list
    - print current recipient key files

  rekey
    - re-encrypt all secrets/*.age via agenix -r
EOF
}

require_main_identity() {
  local identity_file="$1"
  if [ ! -f "$identity_file" ]; then
    echo "error: missing $identity_file" >&2
    echo "hint: import the existing main key or run scripts/bootstrap-age-key.sh --create (first bootstrap only)." >&2
    exit 1
  fi
}

repo_root="$(enter_repo_root)"
key_dir="$repo_root/.keys"
secrets_key_dir="$repo_root/secrets/keys"
host_key_dir="$secrets_key_dir/hosts"
main_identity="$key_dir/main.agekey"
recovery_identity="$key_dir/recovery.agekey"
recovery_pub="$secrets_key_dir/recovery.age.pub"

cmd="${1:-}"
if [ -z "$cmd" ]; then
  usage >&2
  exit 2
fi
shift || true

mkdir -p "$key_dir" "$secrets_key_dir" "$host_key_dir"

case "$cmd" in
  init-recovery)
    force=0
    if [ "${1:-}" = "--force" ]; then
      force=1
      shift
    fi
    if [ "$#" -ne 0 ]; then
      echo "error: unexpected arguments for init-recovery" >&2
      exit 2
    fi

    if [ "$force" -eq 1 ] || [ ! -f "$recovery_identity" ]; then
      run_age_keygen -o "$recovery_identity" >/dev/null
      echo "recovery identity ready: $recovery_identity"
    fi
    chmod 0400 "$recovery_identity"
    run_age_keygen -y "$recovery_identity" > "$recovery_pub"
    echo "recovery recipient updated: $recovery_pub"
    ;;

  add-host)
    host="${1:-}"
    pub_src="${2:-/etc/ssh/ssh_host_ed25519_key.pub}"
    if [ -z "$host" ]; then
      echo "error: host is required" >&2
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

    first_field="$(awk '{print $1}' "$pub_src" | head -n 1)"
    second_field="$(awk '{print $2}' "$pub_src" | head -n 1)"
    if [ "$first_field" != "ssh-ed25519" ] || [ -z "$second_field" ]; then
      echo "error: invalid ssh-ed25519 public key file: $pub_src" >&2
      exit 1
    fi

    target="$host_key_dir/${host}.ssh_host_ed25519.pub"
    cp "$pub_src" "$target"
    chmod 0644 "$target"
    echo "host recipient updated: $target"
    ;;

  list)
    echo "recipient files:"
    if [ -f "$secrets_key_dir/main.age.pub" ]; then
      echo "- secrets/keys/main.age.pub"
    fi
    if [ -f "$recovery_pub" ]; then
      echo "- secrets/keys/recovery.age.pub"
    fi
    find "$host_key_dir" -maxdepth 1 -type f -name '*.pub' -print \
      | sed "s|^$repo_root/|- |" \
      | sort
    ;;

  rekey)
    require_main_identity "$main_identity"
    if [ ! -f "$repo_root/secrets.nix" ]; then
      echo "error: missing $repo_root/secrets.nix" >&2
      exit 1
    fi

    if [ -f "$recovery_identity" ]; then
      run_agenix -r -i "$main_identity" -i "$recovery_identity"
    else
      run_agenix -r -i "$main_identity"
    fi
    echo "rekey completed."
    ;;

  *)
    echo "error: unknown command '$cmd'" >&2
    usage >&2
    exit 2
    ;;
esac
