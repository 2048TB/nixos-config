#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/deploy-host.sh nixos <host>
  ./scripts/deploy-host.sh darwin <host>
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

registry_value() {
  local platform_name=$1
  local host_name=$2
  local field_name=$3

  nix eval --impure --raw --expr "
    let
      registry = builtins.fromTOML (builtins.readFile \"$repo_root/nix/registry/systems.toml\");
      platformSet = builtins.getAttr \"$platform_name\" registry;
      hostSet = builtins.getAttr \"$host_name\" platformSet;
    in
    builtins.getAttr \"$field_name\" hostSet
  "
}

deploy_host=$(registry_value "$platform" "$host" "deployHost")
deploy_user=$(registry_value "$platform" "$host" "deployUser")
target="${deploy_user}@${deploy_host}"
current_host=$(hostname -s || true)

case "$platform" in
  nixos)
    if ! command -v nixos-rebuild >/dev/null; then
      echo "Missing required command: nixos-rebuild" >&2
      exit 1
    fi
    ./scripts/preflight-switch.sh nixos "$host"
    nixos-rebuild switch --flake "$repo_root#$host" --target-host "$target" --use-remote-sudo
    ;;
  darwin)
    if [[ "$current_host" != "$host" && "$current_host" != "$deploy_host" ]]; then
      echo "Darwin deploy is only supported when run on the target host. Run this script on '$deploy_host'." >&2
      exit 1
    fi
    if ! command -v darwin-rebuild >/dev/null; then
      echo "Missing required command: darwin-rebuild" >&2
      exit 1
    fi
    ./scripts/preflight-switch.sh darwin "$host"
    darwin-rebuild switch --flake "$repo_root#$host"
    ;;
  *)
    echo "Unknown platform: $platform" >&2
    usage >&2
    exit 1
    ;;
esac
