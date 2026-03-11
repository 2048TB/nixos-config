#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/../admin/common.sh"

repo_root="$(resolve_repo_path "${NIXOS_CONFIG_REPO:-$PWD}")"
cd "$repo_root"

echo "==> parse host registry"
nix eval --json --impure --expr "
  builtins.fromTOML (builtins.readFile \"${repo_root}/nix/hosts/registry/systems.toml\")
" >/dev/null

echo "==> evaluate registered nixos hosts"
nix eval --json "path:${repo_root}#nixosConfigurations" --apply builtins.attrNames >/dev/null

echo "==> evaluate registered darwin hosts"
nix eval --json "path:${repo_root}#darwinConfigurations" --apply builtins.attrNames >/dev/null
