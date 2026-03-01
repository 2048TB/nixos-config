#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 '<sha512-hash>'" >&2
  exit 1
fi

password_hash="$1"
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

recipient_file="$repo_root/secrets/keys/main.age.pub"
user_secret_rel="./secrets/passwords/user-password.age"
root_secret_rel="./secrets/passwords/root-password.age"
user_secret="$repo_root/secrets/passwords/user-password.age"
root_secret="$repo_root/secrets/passwords/root-password.age"

if [ ! -f "$recipient_file" ]; then
  echo "missing $recipient_file; run scripts/bootstrap-age-key.sh first" >&2
  exit 1
fi

recipient="$(tr -d '\n' < "$recipient_file")"
if [ -z "$recipient" ]; then
  echo "empty recipient in $recipient_file" >&2
  exit 1
fi

mkdir -p "$(dirname "$user_secret")"

run_agenix() {
  if command -v agenix >/dev/null 2>&1; then
    agenix "$@"
  else
    nix run github:ryantm/agenix -- "$@"
  fi
}

encrypt_with_agenix() {
  local target_rel="$1"
  # Non-interactive mode: agenix will use `cp /dev/stdin` as editor.
  printf '%s\n' "$password_hash" | run_agenix -e "$target_rel" -i "$repo_root/.keys/main.agekey"
}

encrypt_with_agenix "$user_secret_rel"
encrypt_with_agenix "$root_secret_rel"

echo "updated agenix password secrets:"
echo "- $user_secret"
echo "- $root_secret"
