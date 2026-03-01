#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"

repo_root="$(enter_repo_root)"

key_dir="$repo_root/.keys"
key_file="$key_dir/main.agekey"
pub_dir="$repo_root/secrets/keys"
pub_file="$pub_dir/main.age.pub"

usage() {
  cat <<'EOF'
usage:
  bootstrap-age-key.sh [--create] [--rotate]

behavior:
  - default: require existing .keys/main.agekey, then refresh secrets/keys/main.age.pub
  - --create: create main.agekey only when it does not exist
  - --rotate: force-generate a new main.agekey (dangerous; requires rekey)
EOF
}

mode="default"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --create)
      mode="create"
      shift
      ;;
    --rotate)
      mode="rotate"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$key_dir" "$pub_dir"

case "$mode" in
  default)
    if [ ! -f "$key_file" ]; then
      echo "error: missing $key_file" >&2
      echo "hint: import your existing main key first, then rerun." >&2
      echo "      use --create only for the very first bootstrap." >&2
      exit 1
    fi
    ;;
  create)
    if [ ! -f "$key_file" ]; then
      run_age_keygen -o "$key_file" >/dev/null
      echo "created new main key: $key_file"
    fi
    ;;
  rotate)
    run_age_keygen -o "$key_file" >/dev/null
    echo "rotated main key: $key_file"
    echo "warning: run agenix rekey before next deployment."
    ;;
esac

chmod 0400 "$key_file"

run_age_keygen -y "$key_file" > "$pub_file"

echo "agenix key ready:"
echo "- private: $key_file"
echo "- public : $pub_file"
