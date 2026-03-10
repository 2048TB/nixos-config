#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/post-switch-check.sh nixos <host>
  ./scripts/post-switch-check.sh darwin <host>
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

check_command() {
  local cmd=$1
  echo "==> command: $cmd"
  if ! command -v "$cmd" >/dev/null; then
    echo "missing command in PATH: $cmd" >&2
    exit 1
  fi
}

check_systemd_unit() {
  local unit=$1
  echo "==> systemd unit: $unit"
  if ! systemctl is-enabled "$unit" >/dev/null; then
    echo "systemd unit is not enabled: $unit" >&2
    exit 1
  fi
}

check_nix_bool() {
  local attr=$1
  echo "==> nix bool: $attr"
  if ! nix eval --json "$attr" | grep -qx 'true'; then
    echo "expected true for: $attr" >&2
    exit 1
  fi
}

current_host=$(hostname -s || true)
if [[ "$current_host" != "$host" ]]; then
  echo "runtime checks skipped: current host is '$current_host', target is '$host'"
  exit 0
fi

case "$platform" in
  nixos)
    check_command nh
    check_command snapper

    check_systemd_unit nix-gc.timer
    check_systemd_unit snapper-cleanup.timer
    check_systemd_unit snapper-timeline.timer
    check_systemd_unit btrfs-scrub@-.timer
    check_systemd_unit NetworkManager.service

    if check_nix_bool ".#nixosConfigurations.${host}.config.services.greetd.enable"; then
      check_systemd_unit greetd.service
    fi

    if check_nix_bool ".#nixosConfigurations.${host}.config.services.mullvad-vpn.enable"; then
      check_systemd_unit mullvad-daemon.service
    fi

    if check_nix_bool ".#nixosConfigurations.${host}.config.virtualisation.libvirtd.enable"; then
      check_systemd_unit libvirtd.service
    fi

    resume_device=$(nix eval --raw ".#nixosConfigurations.${host}.config.boot.resumeDevice")
    if [[ -n "$resume_device" ]]; then
      ./scripts/check-resume.sh "$host"
    fi

    echo "post-switch checks passed for nixos:${host}"
    ;;
  darwin)
    check_command nix
    check_command home-manager
    check_command nh

    check_nix_bool ".#darwinConfigurations.${host}.config.nix.gc.automatic"
    nix eval --raw ".#darwinConfigurations.${host}.config.networking.hostName" | grep -qx "$host"

    echo "post-switch checks passed for darwin:${host}"
    ;;
  *)
    echo "Unknown platform: $platform" >&2
    usage >&2
    exit 1
    ;;
esac
