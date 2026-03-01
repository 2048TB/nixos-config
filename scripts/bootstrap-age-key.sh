#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

key_dir="$repo_root/.keys"
key_file="$key_dir/main.agekey"
pub_dir="$repo_root/secrets/keys"
pub_file="$pub_dir/main.age.pub"

mkdir -p "$key_dir" "$pub_dir"

if [ ! -f "$key_file" ]; then
  if command -v age-keygen >/dev/null 2>&1; then
    age-keygen -o "$key_file" >/dev/null
  else
    nix shell nixpkgs#age -c age-keygen -o "$key_file" >/dev/null
  fi
fi

chmod 0400 "$key_file"

if command -v age-keygen >/dev/null 2>&1; then
  age-keygen -y "$key_file" > "$pub_file"
else
  nix shell nixpkgs#age -c age-keygen -y "$key_file" > "$pub_file"
fi

echo "agenix key ready:"
echo "- private: $key_file"
echo "- public : $pub_file"
