#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  cat <<'EOF' >&2
Usage:
  ./scripts/list-hosts.sh <nixos|darwin> [repo_root]
EOF
  exit 1
fi

platform=$1
repo_root=${2:-.}

case "$platform" in
  nixos|darwin)
    ;;
  *)
    echo "unsupported platform: $platform" >&2
    exit 1
    ;;
esac

cd "$repo_root"

nix eval --raw --file - <<EOF
let
  registry = builtins.fromTOML (builtins.readFile ./nix/registry/systems.toml);
  hosts = builtins.sort builtins.lessThan (builtins.attrNames (registry.${platform} or {}));
in
builtins.concatStringsSep "\n" hosts
EOF
