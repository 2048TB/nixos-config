#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
bash_bin=$(command -v bash)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/tree/nix"
touch "$tmpdir/tree/flake.nix" "$tmpdir/tree/nix/module.nix" "$tmpdir/tree/nix/ignore.txt"

ln -s "$(command -v find)" "$tmpdir/bin/find"

actual=$(
  PATH="$tmpdir/bin" \
    "$bash_bin" "$repo_root/scripts/list-nix-files.sh" "$tmpdir/tree" | sort
)

expected=$'flake.nix\nnix/module.nix'

if [[ "$actual" != "$expected" ]]; then
  echo "unexpected output from list-nix-files.sh without rg" >&2
  echo "expected:" >&2
  printf '%s\n' "$expected" >&2
  echo "actual:" >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi
