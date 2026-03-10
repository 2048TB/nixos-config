#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

if rg -n '^_:\s*\{\s*\}$|^\{[^}]*\}:\s*\{\s*\}$' \
  "$repo_root/nix/nixos/roles" \
  "$repo_root/nix/hosts" \
  -g '*.nix' >/dev/null; then
  echo "empty active Nix modules are not allowed" >&2
  rg -n '^_:\s*\{\s*\}$|^\{[^}]*\}:\s*\{\s*\}$' \
    "$repo_root/nix/nixos/roles" \
    "$repo_root/nix/hosts" \
    -g '*.nix' >&2
  exit 1
fi
