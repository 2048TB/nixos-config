#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"

if [ $# -ne 1 ]; then
  echo "usage: $0 '<sha512-hash>'" >&2
  exit 1
fi

password_hash="$1"
repo_root="$(enter_repo_root)"

recipient_file="$repo_root/secrets/keys/main.age.pub"
user_secret_rel="./secrets/passwords/user-password.age"
root_secret_rel="./secrets/passwords/root-password.age"
user_secret="$repo_root/secrets/passwords/user-password.age"
root_secret="$repo_root/secrets/passwords/root-password.age"
identity_file="$repo_root/.keys/main.agekey"

if [ ! -f "$recipient_file" ]; then
  echo "missing $recipient_file; run scripts/bootstrap-age-key.sh first" >&2
  exit 1
fi

if [ ! -f "$identity_file" ]; then
  echo "missing $identity_file; run scripts/bootstrap-age-key.sh first" >&2
  exit 1
fi

if [ -z "$(tr -d '\n' < "$recipient_file")" ]; then
  echo "empty public key file: $recipient_file" >&2
  exit 1
fi

mkdir -p "$(dirname "$user_secret")"

encrypt_with_agenix() {
  local target_rel="$1"
  # Non-interactive mode: agenix will use `cp /dev/stdin` as editor.
  printf '%s\n' "$password_hash" | run_agenix -e "$target_rel" -i "$identity_file"
}

encrypt_with_agenix "$user_secret_rel"
encrypt_with_agenix "$root_secret_rel"

echo "updated agenix password secrets:"
echo "- $user_secret"
echo "- $root_secret"
