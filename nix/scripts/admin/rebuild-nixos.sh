#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

usage() {
  cat <<'EOF'
Usage:
  rebuild-nixos.sh <switch|boot|test|check> [host] [repo]
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
  switch | boot | test | check) ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "error: unsupported nixos action '$action'" >&2
    usage >&2
    exit 2
    ;;
esac

repo="$(resolve_repo_path "$repo")"

if [ -z "$host" ]; then
  host="$(bash "$script_dir/resolve-host.sh" nixos "$repo" auto --strict)"
fi

echo ">>> host=$host"

case "$action" in
  switch | boot | test)
    if [ "${REBUILD_PREFLIGHT:-0}" = "1" ]; then
      bash "$script_dir/preflight-switch.sh" nixos "$host"
    fi
    sudo nixos-rebuild "$action" --flake "path:${repo}#$host" |& nom
    ;;
  check)
    "${nix_cmd[@]}" build --no-link "path:${repo}#nixosConfigurations.$host.config.system.build.toplevel"
    ;;
esac
