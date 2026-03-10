#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/preflight-switch.sh nixos <host>
  ./scripts/preflight-switch.sh darwin <host>
EOF
}

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 1
fi

platform=$1
host=$2
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

cd "$repo_root"

require_nix_attr() {
  local attr=$1
  nix eval --raw "$attr" >/dev/null
}

echo "==> verify docs/hosts.md is in sync"
./scripts/generate-hosts-doc.sh --check

echo "==> nix flake check"
nix flake check

case "$platform" in
  nixos)
    echo "==> validate host metadata and key options for nixos:${host}"
    require_nix_attr ".#nixosConfigurations.${host}.config.networking.hostName"
    require_nix_attr ".#nixosConfigurations.${host}.config.services.snapper.configs.root.SUBVOLUME"
    nix eval --json ".#nixosConfigurations.${host}.config.programs.nh.enable" | grep -qx 'true'
    if nix eval --json ".#nixosConfigurations.${host}.config.boot.resumeDevice != null" | grep -qx 'true'; then
      nix eval --raw ".#nixosConfigurations.${host}.config.boot.resumeDevice" | grep -q .
    fi
    echo "==> dry-run nixosConfigurations.${host}"
    nix build --dry-run ".#nixosConfigurations.${host}.config.system.build.toplevel"
    ;;
  darwin)
    echo "==> validate host metadata for darwin:${host}"
    require_nix_attr ".#darwinConfigurations.${host}.config.networking.hostName"
    echo "==> dry-run darwinConfigurations.${host}"
    nix build --dry-run ".#darwinConfigurations.${host}.system"
    ;;
  *)
    echo "Unknown platform: $platform" >&2
    usage >&2
    exit 1
    ;;
esac

echo "==> preflight passed for ${platform}:${host}"
