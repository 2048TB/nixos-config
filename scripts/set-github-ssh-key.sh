#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"

repo_root="$(enter_repo_root)"

private_src="$repo_root/.keys/github_id_ed25519"
public_src="$repo_root/.keys/github_id_ed25519.pub"
private_secret_rel="./secrets/ssh/github_id_ed25519.age"
public_secret_rel="./secrets/ssh/github_id_ed25519.pub.age"
private_secret="$repo_root/secrets/ssh/github_id_ed25519.age"
public_secret="$repo_root/secrets/ssh/github_id_ed25519.pub.age"
identity_file="$repo_root/.keys/main.agekey"

if [ ! -f "$private_src" ]; then
  echo "missing $private_src" >&2
  echo "hint: place your SSH private key at .keys/github_id_ed25519 first" >&2
  exit 1
fi

if [ ! -f "$identity_file" ]; then
  echo "missing $identity_file; run scripts/bootstrap-age-key.sh first" >&2
  exit 1
fi

if [ ! -f "$public_src" ]; then
  run_ssh_keygen -y -f "$private_src" > "$public_src"
fi

chmod 0600 "$private_src"
chmod 0644 "$public_src"
mkdir -p "$(dirname "$private_secret")"

# Non-interactive mode: agenix will use `cp /dev/stdin` as editor.
cat "$private_src" | run_agenix -e "$private_secret_rel" -i "$identity_file"
cat "$public_src" | run_agenix -e "$public_secret_rel" -i "$identity_file"

echo "updated agenix ssh key secrets:"
echo "- $private_secret"
echo "- $public_secret"
