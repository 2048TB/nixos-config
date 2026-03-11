#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

usage() {
  cat <<'EOF'
Usage:
  rebuild-darwin.sh <switch|check> [host] [repo]
EOF
}

action="${1:-}"
host="${2:-}"
repo="${3:-${NIXOS_CONFIG_REPO:-$PWD}}"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")

if [ -z "$action" ]; then
  usage >&2
  exit 1
fi

case "$action" in
  switch | check) ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "error: unsupported darwin action '$action'" >&2
    usage >&2
    exit 2
    ;;
esac

repo="$(resolve_repo_path "$repo")"

if [ -z "$host" ]; then
  host="$(bash "$script_dir/resolve-host.sh" darwin "$repo" auto --strict)"
fi

echo ">>> darwin_host=$host"

case "$action" in
  switch)
    bash "$script_dir/preflight-switch.sh" darwin "$host"
    darwin-rebuild switch --flake "path:${repo}#$host"
    ;;
  check)
    "${nix_cmd[@]}" build --no-link "path:${repo}#darwinConfigurations.$host.system"
    ;;
esac
