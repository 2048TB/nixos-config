#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"

output="$(bash "$repo_root/nix/scripts/admin/repo-check.sh" --bad-flag 2>&1 || true)"

if [[ "$output" != *"Usage:"* ]]; then
  echo "expected usage output, got: $output" >&2
  exit 1
fi
