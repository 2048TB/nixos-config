#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

usage() {
  cat <<'EOF'
Usage:
  update-flake.sh [repo] [input...]

Examples:
  update-flake.sh /persistent/nixos-config
  update-flake.sh /persistent/nixos-config nixpkgs
  update-flake.sh /persistent/nixos-config nixpkgs nixpkgs-unstable
EOF
}

if [[ "${1:-}" = "-h" || "${1:-}" = "--help" ]]; then
  usage
  exit 0
fi

if [ "$#" -gt 0 ] && [[ "${1:-}" != -* ]]; then
  repo_root="$(resolve_repo_path "$1")"
  shift
else
  repo_root="$(
    if [ -n "${NIXOS_CONFIG_REPO:-}" ]; then
      resolve_repo_path "$NIXOS_CONFIG_REPO"
    else
      resolve_repo_path
    fi
  )"
fi
input_names=("$@")
nix_cmd=(nix --extra-experimental-features "nix-command flakes" flake update)

prepare_flake_repo_path "$repo_root"
flake_repo="$PREPARED_FLAKE_REPO"

if [ "${#input_names[@]}" -gt 0 ]; then
  nix_cmd+=("${input_names[@]}")
fi
nix_cmd+=(--flake "path:${flake_repo}")

"${nix_cmd[@]}"

if [ "$flake_repo" != "$repo_root" ]; then
  cp "$flake_repo/flake.lock" "$repo_root/flake.lock"
fi

echo "flake.lock updated"
