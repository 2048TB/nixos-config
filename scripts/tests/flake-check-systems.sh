#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

expected=$(nix eval --impure --json --expr '[ builtins.currentSystem ]')

for output_name in formatter devShells apps checks; do
  actual=$(
    nix eval --impure --json --expr "builtins.attrNames (builtins.getFlake (toString $repo_root)).${output_name}"
  )

  if [[ "$actual" != "$expected" ]]; then
    echo "unexpected ${output_name} systems" >&2
    echo "expected: $expected" >&2
    echo "actual:   $actual" >&2
    exit 1
  fi
done
