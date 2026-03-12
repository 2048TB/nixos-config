#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

repo_root="$(resolve_repo_path "${1:-${NIXOS_CONFIG_REPO:-$PWD}}")"
prepare_flake_repo_path "$repo_root"
flake_repo="$PREPARED_FLAKE_REPO"

nix --extra-experimental-features 'nix-command flakes' flake check --all-systems "path:${flake_repo}"
echo "✓ Flake 配置检查通过"
