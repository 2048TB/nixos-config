#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

repo_root="$(resolve_repo_path "${1:-${NIXOS_CONFIG_REPO:-$PWD}}")"
prepare_flake_repo_path "$repo_root"
flake_repo="$PREPARED_FLAKE_REPO"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")

echo "=== checks.x86_64-linux (eval tests) ==="
"${nix_cmd[@]}" build --no-link \
  "path:${flake_repo}#checks.x86_64-linux.evaltest-hostname" \
  "path:${flake_repo}#checks.x86_64-linux.evaltest-home" \
  "path:${flake_repo}#checks.x86_64-linux.evaltest-kernel" \
  "path:${flake_repo}#checks.x86_64-linux.evaltest-platform"

echo ""
echo "=== checks.aarch64-darwin (eval only) ==="
"${nix_cmd[@]}" eval "path:${flake_repo}#checks.aarch64-darwin.evaltest-darwin-hostname.drvPath" >/dev/null
"${nix_cmd[@]}" eval "path:${flake_repo}#checks.aarch64-darwin.evaltest-darwin-home.drvPath" >/dev/null
"${nix_cmd[@]}" eval "path:${flake_repo}#checks.aarch64-darwin.evaltest-darwin-platform.drvPath" >/dev/null
