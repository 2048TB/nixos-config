#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

usage() {
  cat <<'EOF'
usage:
  install-live.sh --host <name> --disk <device> [--repo <path>] [--yes]

examples:
  install-live.sh --host zly --disk /dev/nvme0n1
  install-live.sh --host zky --disk /dev/sda --repo /path/to/repo
EOF
}

host=""
disk=""
repo="${NIXOS_CONFIG_REPO:-$PWD}"
assume_yes=0
key_dir_rel=".keys"
age_key_rel="$key_dir_rel/main.agekey"

is_age_private_key_file() {
  local path="${1:-}"
  local first_data_line=""
  [ -r "$path" ] || return 1
  first_data_line="$(
    awk '
      {
        line = $0
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line == "" || line ~ /^#/) {
          next
        }
        print line
        exit
      }
    ' "$path"
  )"
  [[ "$first_data_line" == AGE-SECRET-KEY-* ]]
}

resolve_age_key_src() {
  declare -A seen=()
  local candidates=(
    "$PWD/$age_key_rel"
    "$repo/$age_key_rel"
    "${HOME:-}/$age_key_rel"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    [ -n "$candidate" ] || continue
    if [ -n "${seen[$candidate]:-}" ]; then
      continue
    fi
    seen[$candidate]=1
    [ -f "$candidate" ] || continue
    if is_age_private_key_file "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
    echo "warning: ignore invalid age key file (expected AGE-SECRET-KEY-*): $candidate" >&2
  done
  return 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) host="${2:-}"; shift 2 ;;
    --disk) disk="${2:-}"; shift 2 ;;
    --repo) repo="${2:-}"; shift 2 ;;
    --yes) assume_yes=1; shift ;;
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
validate_block_device_path "$disk"
confirm_destructive_action \
  "INSTALL ${host} ${disk}" \
  "warning: this will erase disk ${disk} and install host ${host} from repo ${repo}" \
  "$assume_yes"

echo ">>> host=$host disk=$disk"

# 1. Run disko
disko_script="$(env NIXOS_DISK_DEVICE="$disk" nix build --impure --no-link --print-out-paths "path:${repo}#nixosConfigurations.${host}.config.system.build.diskoScript")"
echo ">>> disko_script=$disko_script"
sudo env NIXOS_DISK_DEVICE="$disk" "$disko_script"

# 2. Verify mounts
findmnt /mnt/boot
findmnt /mnt/persistent

# 3. Install sops age key
if age_key_src="$(resolve_age_key_src)"; then
  sudo install -D -m 0400 -o root -g root "$age_key_src" /mnt/persistent/keys/main.agekey
  echo ">>> sops key installed: $age_key_src -> /mnt/persistent/keys/main.agekey"
else
  echo "error: sops key not found (or invalid) in search paths below:" >&2
  echo "  - $PWD/$age_key_rel" >&2
  echo "  - $repo/$age_key_rel" >&2
  echo "  - ${HOME:-}/$age_key_rel" >&2
  echo "hint: place AGE private key 'main.agekey' into one of these paths, then retry." >&2
  exit 1
fi

# 4. Run nixos-install (from source repo)
sudo env NIXOS_DISK_DEVICE="$disk" nixos-install --impure --flake "path:${repo}#$host"

# 5. Sync flake into target /persistent/nixos-config (atomic replace)
TARGET_FLAKE_DIR="/mnt/persistent/nixos-config"
TARGET_FLAKE_TMP="${TARGET_FLAKE_DIR}.tmp.$$"
if ! sudo findmnt /mnt/persistent >/dev/null 2>&1; then
  echo "error: /mnt/persistent is not mounted. refusing to sync flake" >&2
  exit 1
fi

sudo rm -rf "$TARGET_FLAKE_TMP"
sudo mkdir -p "$TARGET_FLAKE_TMP"
sudo cp -a "$repo/." "$TARGET_FLAKE_TMP/"
# Keep decrypt key in repo copy for post-install sops workflows.
sudo install -D -m 0400 -o root -g root "$age_key_src" "$TARGET_FLAKE_TMP/.keys/main.agekey"
if [ ! -f "$TARGET_FLAKE_TMP/flake.nix" ]; then
  echo "error: synced target flake is incomplete: missing flake.nix" >&2
  exit 1
fi

target_user="$(nix eval --raw "path:${repo}#nixosConfigurations.${host}.config.my.host.username")"
target_owner="$(resolve_target_owner_from_config "$repo" "$host" "$target_user")"
sudo chown -R "$target_owner" "$TARGET_FLAKE_TMP"
sudo rm -rf "$TARGET_FLAKE_DIR"
sudo mv "$TARGET_FLAKE_TMP" "$TARGET_FLAKE_DIR"

# 6. Ensure target /etc/nixos points to persistent repo
sudo rm -rf /mnt/etc/nixos
sudo ln -sfn /persistent/nixos-config /mnt/etc/nixos

# 7. Verify target flake (dry-build)
sudo nixos-rebuild dry-build --flake /mnt/persistent/nixos-config#"$host"

echo ">>> github ssh key will be provisioned by sops secrets on first boot/switch (if configured)"
echo "done: reboot, then run: just host=$host switch"
