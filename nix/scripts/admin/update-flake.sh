#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

usage() {
  cat <<'EOF'
Usage:
  update-flake.sh [repo] [input]

Examples:
  update-flake.sh /persistent/nixos-config
  update-flake.sh /persistent/nixos-config nixpkgs
EOF
}

if [[ "${1:-}" = "-h" || "${1:-}" = "--help" ]]; then
  usage
  exit 0
fi

repo_root="$(resolve_repo_path "${1:-${NIXOS_CONFIG_REPO:-$PWD}}")"
input_name="${2:-}"
nix_cmd=(nix --extra-experimental-features "nix-command flakes" flake update)

prepare_flake_repo_path "$repo_root"
flake_repo="$PREPARED_FLAKE_REPO"

if [ -n "$input_name" ]; then
  nix_cmd+=("$input_name")
fi
nix_cmd+=(--flake "path:${flake_repo}")

"${nix_cmd[@]}"

if [ "$flake_repo" != "$repo_root" ]; then
  cp "$flake_repo/flake.lock" "$repo_root/flake.lock"
fi

echo "✓ flake.lock 已更新"
