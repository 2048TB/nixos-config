#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"

# shellcheck disable=SC1091
source "$repo_root/nix/scripts/admin/common.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

input_file="$tmpdir/input"
cat >"$input_file" <<'EOF'
warning: unknown flake output 'homeManagerModules'
checking flake output 'checks'...
another real warning
EOF

output="$(
  filter_known_flake_warnings <"$input_file"
)"

if [[ "$output" == *"unknown flake output 'homeManagerModules'"* ]]; then
  echo "expected known homeManagerModules warning to be filtered" >&2
  exit 1
fi

if [[ "$output" != *"checking flake output 'checks'..."* ]]; then
  echo "expected regular flake-check stderr to be preserved" >&2
  exit 1
fi

if [[ "$output" != *"another real warning"* ]]; then
  echo "expected unrelated warnings to be preserved" >&2
  exit 1
fi
