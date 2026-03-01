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

mkdir -p "$key_dir" "$pub_dir"

if [ ! -f "$key_file" ]; then
  run_age_keygen -o "$key_file" >/dev/null
fi

chmod 0400 "$key_file"

run_age_keygen -y "$key_file" > "$pub_file"

echo "agenix key ready:"
echo "- private: $key_file"
echo "- public : $pub_file"
