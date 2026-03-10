#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/rebuild-host.sh nixos <host> <build|test|dry-activate|switch|build-vm>
  ./scripts/rebuild-host.sh darwin <host> <build|switch>
EOF
}

if [[ $# -ne 3 ]]; then
  usage >&2
  exit 1
fi

platform=$1
host=$2
action=$3
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

cd "$repo_root"

require_command() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

require_current_host() {
  local current_host
  current_host=$(hostname -s || true)
  if [[ "$current_host" != "$host" ]]; then
    echo "This action must run on host '$host', current host is '$current_host'." >&2
    exit 1
  fi
}

case "$platform" in
  nixos)
    require_command nixos-rebuild
    case "$action" in
      build)
        nixos-rebuild build --flake "$repo_root#$host"
        ;;
      test)
        ./scripts/preflight-switch.sh nixos "$host"
        require_current_host
        sudo nixos-rebuild test --flake "$repo_root#$host"
        ;;
      dry-activate)
        require_current_host
        sudo nixos-rebuild dry-activate --flake "$repo_root#$host"
        ;;
      switch)
        ./scripts/preflight-switch.sh nixos "$host"
        require_current_host
        sudo nixos-rebuild switch --flake "$repo_root#$host"
        ;;
      build-vm)
        nixos-rebuild build-vm --flake "$repo_root#$host"
        ;;
      *)
        echo "Unsupported nixos action: $action" >&2
        usage >&2
        exit 1
        ;;
    esac
    ;;
  darwin)
    case "$action" in
      build)
        require_command nix
        nix build ".#darwinConfigurations.${host}.system"
        ;;
      switch)
        require_command darwin-rebuild
        ./scripts/preflight-switch.sh darwin "$host"
        require_current_host
        darwin-rebuild switch --flake "$repo_root#$host"
        ;;
      *)
        echo "Unsupported darwin action: $action" >&2
        usage >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Unknown platform: $platform" >&2
    usage >&2
    exit 1
    ;;
esac
