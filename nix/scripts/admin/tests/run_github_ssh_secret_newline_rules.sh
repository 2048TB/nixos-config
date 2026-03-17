#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
target="$repo_root/nix/scripts/admin/sops.sh"

rg -Uq 'echo "value: \|"\n[[:space:]]*sed .*"\$private_src"\n[[:space:]]*\} \| encrypt_yaml_to_target "\$private_secret"' "$target"
rg -Uq 'echo "value: \|-"\n[[:space:]]*sed .*"\$public_src"\n[[:space:]]*\} \| encrypt_yaml_to_target "\$public_secret"' "$target"
