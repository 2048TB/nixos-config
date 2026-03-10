#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  preflight-switch.sh nixos <host>
  preflight-switch.sh darwin <host>
EOF
}

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 1
fi

platform="$1"
host="$2"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

repo_root="$(resolve_repo_path "${NIXOS_CONFIG_REPO:-$PWD}")"
cd "$repo_root"

bash "$script_dir/repo-check.sh"

case "$platform" in
  nixos)
    echo "==> dry-build nixos:$host"
    nix build --no-link "path:$repo_root#nixosConfigurations.$host.config.system.build.toplevel"
    ;;
  darwin)
    echo "==> dry-build darwin:$host"
    nix build --no-link "path:$repo_root#darwinConfigurations.$host.system"
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
