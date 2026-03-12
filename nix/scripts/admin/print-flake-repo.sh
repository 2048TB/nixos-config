#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

if [ "$#" -gt 0 ]; then
  repo_root="$(resolve_repo_path "$1")"
elif [ -n "${NIXOS_CONFIG_REPO:-}" ]; then
  repo_root="$(resolve_repo_path "$NIXOS_CONFIG_REPO")"
else
  repo_root="$(resolve_repo_path)"
fi
prepare_flake_repo_path "$repo_root"
printf '%s\n' "$PREPARED_FLAKE_REPO"
