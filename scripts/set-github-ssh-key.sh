#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

private_src="$repo_root/.keys/github_id_ed25519"
public_src="$repo_root/.keys/github_id_ed25519.pub"
private_secret_rel="./secrets/ssh/github_id_ed25519.age"
public_secret_rel="./secrets/ssh/github_id_ed25519.pub.age"
private_secret="$repo_root/secrets/ssh/github_id_ed25519.age"
public_secret="$repo_root/secrets/ssh/github_id_ed25519.pub.age"

if [ ! -f "$private_src" ]; then
  echo "missing $private_src" >&2
  echo "hint: place your SSH private key at .keys/github_id_ed25519 first" >&2
  exit 1
fi

if [ ! -f "$public_src" ]; then
  if command -v ssh-keygen >/dev/null 2>&1; then
    ssh-keygen -y -f "$private_src" > "$public_src"
  else
    nix shell nixpkgs#openssh -c ssh-keygen -y -f "$private_src" > "$public_src"
  fi
fi

chmod 0600 "$private_src"
chmod 0644 "$public_src"
mkdir -p "$(dirname "$private_secret")"

run_agenix() {
  if command -v agenix >/dev/null 2>&1; then
    agenix "$@"
  else
    nix run github:ryantm/agenix -- "$@"
  fi
}

# Non-interactive mode: agenix will use `cp /dev/stdin` as editor.
cat "$private_src" | run_agenix -e "$private_secret_rel" -i "$repo_root/.keys/main.agekey"
cat "$public_src" | run_agenix -e "$public_secret_rel" -i "$repo_root/.keys/main.agekey"

echo "updated agenix ssh key secrets:"
echo "- $private_secret"
echo "- $public_secret"
