#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  rebuild-auto.sh <nixos|darwin> <action> [host] [repo]
EOF
}

platform="${1:-}"
action="${2:-}"
host="${3:-}"
repo="${4:-${NIXOS_CONFIG_REPO:-$PWD}}"

if [ -z "$platform" ] || [ -z "$action" ]; then
  usage >&2
  exit 1
fi

case "$platform" in
  nixos)
    exec bash "$script_dir/rebuild-nixos.sh" "$action" "$host" "$repo"
    ;;
  darwin)
    exec bash "$script_dir/rebuild-darwin.sh" "$action" "$host" "$repo"
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "error: platform must be 'nixos' or 'darwin', got '$platform'" >&2
    usage >&2
    exit 2
    ;;
esac
