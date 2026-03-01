#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

usage() {
  cat <<'EOF'
usage:
  install-live.sh --host <name> --disk <device> [--repo <path>]

examples:
  install-live.sh --host zly --disk /dev/nvme0n1
  install-live.sh --host zky --disk /dev/sda --repo /path/to/repo
EOF
}

host=""
disk=""
repo="${NIXOS_CONFIG_REPO:-$PWD}"
key_dir_rel=".keys"
age_key_rel="$key_dir_rel/main.agekey"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) host="${2:-}"; shift 2 ;;
    --disk) disk="${2:-}"; shift 2 ;;
    --repo) repo="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$host" ] || [ -z "$disk" ]; then
  echo "error: --host and --disk are required" >&2
  usage >&2
  exit 2
fi

if ! is_valid_host_name "$host"; then
  echo "error: invalid host name '$host'" >&2
  exit 2
fi

repo="$(resolve_repo_path "$repo")"

echo ">>> host=$host disk=$disk"

# 1. Run disko
disko_script="$(env NIXOS_DISK_DEVICE="$disk" nix build --impure --no-link --print-out-paths "path:${repo}#nixosConfigurations.${host}.config.system.build.diskoScript")"
echo ">>> disko_script=$disko_script"
sudo env NIXOS_DISK_DEVICE="$disk" "$disko_script"

# 2. Verify mounts
findmnt /mnt/boot
findmnt /mnt/persistent

# 3. Sync repo to target
sudo rm -rf /mnt/persistent/nixos-config
sudo mkdir -p /mnt/persistent/nixos-config
if command -v rsync >/dev/null 2>&1; then
  sudo rsync -a --delete --exclude='.git' --exclude="$key_dir_rel" "$repo/" /mnt/persistent/nixos-config/
else
  echo "warning: rsync not found, fallback to cp -a (temporary .git copy will be removed)"
  sudo cp -a "$repo/." /mnt/persistent/nixos-config/
  sudo rm -rf /mnt/persistent/nixos-config/.git
  sudo rm -rf "/mnt/persistent/nixos-config/$key_dir_rel"
fi

# 4. Install agenix key
age_key_src="$repo/$age_key_rel"
if [ -f "$age_key_src" ]; then
  sudo install -D -m 0400 -o root -g root "$age_key_src" /mnt/persistent/keys/main.agekey
  echo ">>> agenix key installed: $age_key_src -> /mnt/persistent/keys/main.agekey"
else
  echo "error: agenix key not found at $age_key_src" >&2
  echo "hint: put private key at $repo/$age_key_rel then retry" >&2
  exit 1
fi

# 5. Run nixos-install
sudo env NIXOS_DISK_DEVICE="$disk" nixos-install --impure --flake "/mnt/persistent/nixos-config#$host"

echo ">>> github ssh key will be provisioned by agenix secrets on first boot/switch (if configured)"
echo "done: reboot, then run: just host=$host switch"
