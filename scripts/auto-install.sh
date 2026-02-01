#!/usr/bin/env bash
set -euo pipefail

# NixOS 一键安装脚本
#
# 使用方式：
#   curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/nixos-config/main/scripts/auto-install.sh | sudo bash
#
# 或手动下载后运行：
#   sudo bash auto-install.sh

REPO_URL="${NIXOS_REPO_URL:-https://github.com/2048TB/nixos-config}"
BRANCH="${NIXOS_BRANCH:-main}"

log() {
  echo "[auto-install] $*"
}

fail() {
  echo "[auto-install] ERROR: $*" >&2
  exit 1
}

if [[ $(id -u) -ne 0 ]]; then
  fail "please run as root"
fi

# 检查是否在配置目录中，否则自动下载
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || echo "")"
if [[ -z "$repo_root" ]] || [[ ! -f "$repo_root/flake.nix" ]]; then
  log "Configuration not found, downloading from GitHub..."
  log "Repository: $REPO_URL"
  log "Branch: $BRANCH"

  repo_root="/tmp/nixos-config-$$"
  mkdir -p "$repo_root"

  # 优先使用 curl（ISO 中通常有）
  TARBALL_URL="${REPO_URL}/archive/${BRANCH}.tar.gz"
  if command -v curl >/dev/null 2>&1; then
    log "downloading with curl..."
    curl -sSL "$TARBALL_URL" | tar xz --strip-components=1 -C "$repo_root"
  elif command -v wget >/dev/null 2>&1; then
    log "downloading with wget..."
    wget -qO- "$TARBALL_URL" | tar xz --strip-components=1 -C "$repo_root"
  elif command -v git >/dev/null 2>&1; then
    log "downloading with git..."
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$repo_root"
  else
    fail "no download tool available (curl/wget/git)"
  fi

  if [[ ! -f "$repo_root/flake.nix" ]]; then
    fail "download failed or incomplete"
  fi

  log "configuration downloaded to $repo_root"
fi

log "using configuration from: $repo_root"

required_cmds=(parted mkfs.fat cryptsetup mkfs.btrfs btrfs nixos-generate-config nixos-install openssl)
for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "missing command: $cmd"
  fi
done

if [[ -z "${NIXOS_USER:-}" ]]; then
  read -r -p "Username: " NIXOS_USER
fi

if [[ -z "${NIXOS_PASSWORD:-}" ]]; then
  read -r -s -p "Password: " NIXOS_PASSWORD
  echo
  read -r -s -p "Confirm Password: " NIXOS_PASSWORD_CONFIRM
  echo
  if [[ "$NIXOS_PASSWORD" != "$NIXOS_PASSWORD_CONFIRM" ]]; then
    fail "passwords do not match"
  fi
fi

if [[ -z "${NIXOS_LUKS_PASSWORD:-}" ]]; then
  NIXOS_LUKS_PASSWORD="$NIXOS_PASSWORD"
fi

if [[ -z "${NIXOS_DISK:-}" ]]; then
  mapfile -t nvme_disks < <(ls /dev/nvme*n1 2>/dev/null || true)
  if [[ ${#nvme_disks[@]} -eq 1 ]]; then
    NIXOS_DISK="${nvme_disks[0]}"
  else
    lsblk -d -o NAME,TYPE,SIZE,MODEL
    fail "set NIXOS_DISK (e.g. export NIXOS_DISK=/dev/nvme0n1)"
  fi
fi

if [[ ! -b "$NIXOS_DISK" ]]; then
  fail "disk not found: $NIXOS_DISK"
fi

if [[ -z "${NIXOS_HOSTNAME:-}" ]]; then
  NIXOS_HOSTNAME="nixos-cconfig"
fi

if [[ -z "${NIXOS_GPU:-}" ]]; then
  if grep -qs "0x10de" /sys/bus/pci/devices/*/vendor 2>/dev/null; then
    NIXOS_GPU="nvidia"
  elif grep -qs "0x1002" /sys/bus/pci/devices/*/vendor 2>/dev/null; then
    NIXOS_GPU="amd"
  elif command -v lspci >/dev/null 2>&1; then
    if lspci | grep -Ei "VGA|3D" | grep -qi "nvidia"; then
      NIXOS_GPU="nvidia"
    elif lspci | grep -Ei "VGA|3D" | grep -qi "amd|ati"; then
      NIXOS_GPU="amd"
    else
      NIXOS_GPU="none"
    fi
  else
    NIXOS_GPU="auto"
  fi
fi

SWAP_GB="${NIXOS_SWAP_SIZE_GB:-32}"

log "Configuration Summary:"
log "  disk: $NIXOS_DISK"
log "  hostname: $NIXOS_HOSTNAME"
log "  user: $NIXOS_USER"
log "  gpu: $NIXOS_GPU"
log "  swap size: ${SWAP_GB}G"
log ""
log "WARNING: ALL DATA ON ${NIXOS_DISK} WILL BE ERASED"
log ""
read -r -p "Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  fail "installation cancelled"
fi

part_suffix=""
if [[ "$NIXOS_DISK" =~ [0-9]$ ]]; then
  part_suffix="p"
fi

ESP="${NIXOS_DISK}${part_suffix}1"
ROOT="${NIXOS_DISK}${part_suffix}2"

log "partitioning..."
parted -s "$NIXOS_DISK" mklabel gpt
parted -s "$NIXOS_DISK" mkpart ESP fat32 2MiB 514MiB
parted -s "$NIXOS_DISK" set 1 esp on
parted -s "$NIXOS_DISK" mkpart primary 514MiB 100%

log "formatting ESP..."
mkfs.fat -F 32 -n ESP "$ESP"

log "setting up LUKS..."
printf '%s' "$NIXOS_LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --hash sha512 --iter-time 5000 --key-size 256 --pbkdf argon2id --batch-mode --key-file - "$ROOT"
printf '%s' "$NIXOS_LUKS_PASSWORD" | cryptsetup luksOpen --key-file - "$ROOT" crypted-nixos

log "formatting Btrfs..."
mkfs.btrfs -L crypted-nixos /dev/mapper/crypted-nixos

log "creating subvolumes..."
mount /dev/mapper/crypted-nixos /mnt
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@persistent
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@swap
umount /mnt

log "mounting subvolumes..."
mount -o subvol=@root,compress-force=zstd:1,noatime /dev/mapper/crypted-nixos /mnt
mkdir -p /mnt/{nix,persistent,snapshots,tmp,swap,boot}
mount -o subvol=@nix,compress-force=zstd:1,noatime /dev/mapper/crypted-nixos /mnt/nix
mount -o subvol=@persistent,compress-force=zstd:1 /dev/mapper/crypted-nixos /mnt/persistent
mount -o subvol=@snapshots,compress-force=zstd:1,noatime /dev/mapper/crypted-nixos /mnt/snapshots
mount -o subvol=@tmp,compress-force=zstd:1 /dev/mapper/crypted-nixos /mnt/tmp
mount -o subvol=@swap /dev/mapper/crypted-nixos /mnt/swap
mount "$ESP" /mnt/boot

log "creating swapfile..."
btrfs filesystem mkswapfile --size "${SWAP_GB}g" --uuid clear /mnt/swap/swapfile
swapon /mnt/swap/swapfile

log "generating hardware config..."
nixos-generate-config --root /mnt

log "copying configuration to persistent home..."
mkdir -p "/mnt/persistent/home/${NIXOS_USER}"

# 使用 tar 管道复制（不依赖 git/rsync）
(cd "$repo_root" && tar \
  --exclude=.git \
  --exclude=.github \
  --exclude=result \
  --exclude=nix-config-main \
  --exclude=niri-dotfiles.backup \
  -cf - .) | \
  (cd "/mnt/persistent/home/${NIXOS_USER}" && tar -xf - )

# 重命名目录
mv "/mnt/persistent/home/${NIXOS_USER}" "/mnt/persistent/home/${NIXOS_USER}.tmp"
mkdir -p "/mnt/persistent/home/${NIXOS_USER}"
mv "/mnt/persistent/home/${NIXOS_USER}.tmp" "/mnt/persistent/home/${NIXOS_USER}/nixos-config"

log "writing hardware-configuration.nix..."
cp /mnt/etc/nixos/hardware-configuration.nix \
  "/mnt/persistent/home/${NIXOS_USER}/nixos-config/hosts/nixos-cconfig/hardware-configuration.nix"

log "writing gpu choice..."
printf '%s\n' "$NIXOS_GPU" \
  > "/mnt/persistent/home/${NIXOS_USER}/nixos-config/hosts/nixos-cconfig/gpu-choice.txt"

log "updating vars/default.nix..."
sed -i \
  "s/username = \"[^\"]*\";/username = \"${NIXOS_USER}\";/" \
  "/mnt/persistent/home/${NIXOS_USER}/nixos-config/vars/default.nix"
sed -i \
  "s/hostname = \"[^\"]*\";/hostname = \"${NIXOS_HOSTNAME}\";/" \
  "/mnt/persistent/home/${NIXOS_USER}/nixos-config/vars/default.nix"

log "fixing ownership..."
chown -R 1000:1000 "/mnt/persistent/home/${NIXOS_USER}"

log "writing hashed password..."
mkdir -p /mnt/persistent/etc
printf '%s' "$NIXOS_PASSWORD" | openssl passwd -6 -stdin > /mnt/persistent/etc/user-password
chmod 600 /mnt/persistent/etc/user-password

log "installing NixOS..."
cd "/mnt/persistent/home/${NIXOS_USER}/nixos-config"
NIXOS_GPU="$NIXOS_GPU" \
  nixos-install --impure --flake ".#${NIXOS_HOSTNAME}"

log ""
log "Installation complete!"
log ""
log "Next steps:"
log "  1. reboot"
log "  2. Login with username: $NIXOS_USER"
log "  3. Run: cd ~/nixos-config && sudo nixos-rebuild switch --flake .#${NIXOS_HOSTNAME}"
log ""
