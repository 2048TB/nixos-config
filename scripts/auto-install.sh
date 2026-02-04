#!/usr/bin/env bash
set -euo pipefail

# NixOS 一键安装脚本
#
# 使用方式：
#   curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/nixos-config/main/scripts/auto-install.sh | sudo bash
#
# 或手动下载后运行：
#   sudo bash auto-install.sh

# 配置常量
readonly REPO_URL="${NIXOS_REPO_URL:-https://github.com/2048TB/nixos-config}"
readonly BRANCH="${NIXOS_BRANCH:-main}"
readonly AUTO_ERASE="${NIXOS_AUTO_ERASE:-1}"

# 磁盘分区常量
readonly ESP_SIZE_MIB=512
readonly ESP_START_MIB=2
readonly ESP_END_MIB=$((ESP_START_MIB + ESP_SIZE_MIB))

# Btrfs 挂载选项
readonly BTRFS_OPTS_COMPRESS="compress-force=zstd:1"
readonly BTRFS_OPTS_NOATIME="noatime"

# 默认值
readonly DEFAULT_SWAP_GB=32
readonly DEFAULT_LUKS_ITER_TIME=5000
readonly DEFAULT_UID=1000
readonly DEFAULT_GID_FALLBACK=100
readonly PASSWORD_FILE_MODE=600

log() {
  echo "[auto-install] $*"
}

fail() {
  echo "[auto-install] ERROR: $*" >&2
  exit 1
}

# 清理函数：在脚本退出时自动执行
cleanup() {
  if [[ "${CLEANUP_NEEDED:-0}" == "1" ]]; then
    log "Cleaning up mounts and LUKS..."
    umount -R /mnt 2>/dev/null || true
    swapoff /mnt/swap/swapfile 2>/dev/null || true
    cryptsetup close crypted-nixos 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ $(id -u) -ne 0 ]]; then
  fail "please run as root"
fi

# 检查是否在配置目录中，否则自动下载
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || echo "")"
if [[ -z "$repo_root" ]] || [[ ! -f "$repo_root/flake.nix" ]]; then
  log "Configuration not found, downloading from GitHub..."
  log "Repository: $REPO_URL"
  log "Branch: $BRANCH"

  # 检查网络连接
  if ! curl -sSf --connect-timeout 5 https://github.com > /dev/null 2>&1; then
    if ! wget -q --timeout=5 --spider https://github.com > /dev/null 2>&1; then
      fail "No internet connection. Please ensure network is available or provide config manually"
    fi
  fi

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

required_cmds=(parted mkfs.fat cryptsetup mkfs.btrfs btrfs nixos-generate-config nixos-install tar)
for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "missing command: $cmd (try: nix-shell -p $cmd)"
  fi
done

# 检查密码哈希工具（优先使用 mkpasswd，fallback 到 openssl）
if command -v mkpasswd >/dev/null 2>&1; then
  HASH_CMD="mkpasswd"
elif command -v openssl >/dev/null 2>&1; then
  HASH_CMD="openssl"
else
  fail "missing password hashing tool: install 'mkpasswd' or 'openssl'"
fi

if [[ -z "${NIXOS_USER:-}" ]]; then
  read -r -p "Username: " NIXOS_USER
fi

# 验证用户名格式
if [[ ! "$NIXOS_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  fail "Invalid username: $NIXOS_USER (must start with lowercase letter or underscore, contain only lowercase, digits, underscore, hyphen)"
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
  # 尝试检测各种类型的磁盘（NVMe, SATA, 虚拟机）
  mapfile -t all_disks < <(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}' | grep -E 'nvme[0-9]+n1$|sd[a-z]$|vd[a-z]$|xvd[a-z]$' || true)

  if [[ ${#all_disks[@]} -eq 1 ]]; then
    NIXOS_DISK="${all_disks[0]}"
    log "Auto-detected disk: $NIXOS_DISK"
  elif [[ ${#all_disks[@]} -gt 1 ]]; then
    # 优先选择非可移动/非 USB 的磁盘（避免 U 盘干扰自动检测）
    mapfile -t preferred_disks < <(lsblk -dpno NAME,TYPE,RM,TRAN | awk '$2=="disk" && $3=="0" && $4!="usb"{print $1}' | grep -E 'nvme[0-9]+n1$|sd[a-z]$|vd[a-z]$|xvd[a-z]$' || true)
    if [[ ${#preferred_disks[@]} -eq 1 ]]; then
      NIXOS_DISK="${preferred_disks[0]}"
      log "Auto-detected non-removable disk: $NIXOS_DISK"
    else
      log "Multiple disks found:"
      lsblk -d -o NAME,TYPE,SIZE,MODEL,TRAN,RM
      fail "Multiple disks detected. Please set NIXOS_DISK manually (e.g., NIXOS_DISK=/dev/nvme0n1 sudo -E bash $0)"
    fi
  else
    lsblk -d -o NAME,TYPE,SIZE,MODEL,TRAN,RM
    fail "No suitable disk found. Please set NIXOS_DISK manually (e.g., export NIXOS_DISK=/dev/sda)"
  fi
fi

if [[ ! -b "$NIXOS_DISK" ]]; then
  fail "disk not found: $NIXOS_DISK"
fi

# 检查磁盘是否已有数据（幂等性保护）
if blkid "$NIXOS_DISK" | grep -q "TYPE" && [[ "${FORCE:-0}" != "1" ]]; then
  log "WARNING: Disk $NIXOS_DISK appears to have existing partitions or filesystems:"
  blkid "$NIXOS_DISK"* || true
  log ""
  if [[ "${AUTO_ERASE:-0}" == "1" ]]; then
    log "AUTO_ERASE=1 enabled, proceeding to wipe the disk."
  else
    log "To proceed with installation (THIS WILL ERASE ALL DATA), set FORCE=1:"
    log "  export FORCE=1"
    log "  sudo -E bash $0"
    fail "Installation cancelled for safety. Disk is not empty."
  fi
fi

if [[ -z "${NIXOS_HOSTNAME:-}" ]]; then
  NIXOS_HOSTNAME="nixos-config"
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
    # 检测失败时使用通用驱动而非 "auto"
    log "WARNING: GPU detection failed, falling back to generic modesetting driver"
    NIXOS_GPU="none"
  fi
fi

SWAP_GB="${NIXOS_SWAP_SIZE_GB:-$DEFAULT_SWAP_GB}"

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
parted -s "$NIXOS_DISK" mkpart ESP fat32 "${ESP_START_MIB}MiB" "${ESP_END_MIB}MiB"
parted -s "$NIXOS_DISK" set 1 esp on
parted -s "$NIXOS_DISK" mkpart primary "${ESP_END_MIB}MiB" 100%

log "waiting for partition devices..."
if command -v partprobe >/dev/null 2>&1; then
  partprobe "$NIXOS_DISK" || true
fi
if command -v udevadm >/dev/null 2>&1; then
  udevadm settle || true
fi

log "formatting ESP..."
mkfs.fat -F 32 -n ESP "$ESP"

log "setting up LUKS..."
ITER_TIME="${NIXOS_LUKS_ITER_TIME:-$DEFAULT_LUKS_ITER_TIME}"
printf '%s' "$NIXOS_LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --hash sha512 --iter-time "$ITER_TIME" --key-size 256 --pbkdf argon2id --batch-mode --key-file - "$ROOT"
printf '%s' "$NIXOS_LUKS_PASSWORD" | cryptsetup luksOpen --key-file - "$ROOT" crypted-nixos

# 标记需要清理
CLEANUP_NEEDED=1

log "formatting Btrfs..."
mkfs.btrfs -L crypted-nixos /dev/mapper/crypted-nixos

log "creating subvolumes..."
mount /dev/mapper/crypted-nixos /mnt
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@persistent
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@swap
umount /mnt

log "mounting subvolumes..."
mount -o "subvol=@root,${BTRFS_OPTS_COMPRESS},${BTRFS_OPTS_NOATIME}" /dev/mapper/crypted-nixos /mnt
mkdir -p /mnt/{nix,persistent,home,swap,boot}
mount -o "subvol=@nix,${BTRFS_OPTS_COMPRESS},${BTRFS_OPTS_NOATIME}" /dev/mapper/crypted-nixos /mnt/nix
mount -o "subvol=@persistent,${BTRFS_OPTS_COMPRESS}" /dev/mapper/crypted-nixos /mnt/persistent
mount -o "subvol=@home,compress=zstd,noatime" /dev/mapper/crypted-nixos /mnt/home
mount -o subvol=@swap /dev/mapper/crypted-nixos /mnt/swap
mount "$ESP" /mnt/boot
# 注意：@snapshots 和 @tmp 仅创建子卷备用，安装时不挂载
# - @snapshots: 预留用于 Btrfs 快照功能
# - @tmp: 系统使用内存 tmpfs（性能更优）

log "creating swapfile..."
btrfs filesystem mkswapfile --size "${SWAP_GB}g" --uuid clear /mnt/swap/swapfile

# 验证 swapfile 创建成功
if [[ ! -f /mnt/swap/swapfile ]]; then
  fail "swapfile creation failed"
fi

swapon /mnt/swap/swapfile

log "generating hardware config..."
nixos-generate-config --root /mnt

log "copying configuration to user home..."
# 路径变量（@home 子卷挂载到 /mnt/home）
USER_HOME="/mnt/home/${NIXOS_USER}"
CONFIG_DEST="${USER_HOME}/nixos-config"

mkdir -p "$USER_HOME"

# 使用 tar 管道复制（不依赖 git/rsync）
(cd "$repo_root" && tar \
  --exclude=.git \
  --exclude=.github \
  --exclude=result \
  --exclude=nix-config-main \
  --exclude=niri-dotfiles.backup \
  -cf - .) | \
  (cd "$USER_HOME" && tar -xf - )

# 重命名目录
mv "$USER_HOME" "${USER_HOME}.tmp"
mkdir -p "$USER_HOME"
mv "${USER_HOME}.tmp" "$CONFIG_DEST"

log "writing hardware-configuration.nix..."
cp /mnt/etc/nixos/hardware-configuration.nix \
  "${CONFIG_DEST}/nix/hosts/nixos-config-hardware.nix"

log "writing gpu choice..."
printf '%s\n' "$NIXOS_GPU" \
  > "${CONFIG_DEST}/nix/vars/detected-gpu.txt"

log "updating nix/vars/default.nix..."
VARS_FILE="${CONFIG_DEST}/nix/vars/default.nix"
sed -i \
  "s/username = \"[^\"]*\";/username = \"${NIXOS_USER}\";/" \
  "$VARS_FILE"
sed -i \
  "s/hostname = \"[^\"]*\";/hostname = \"${NIXOS_HOSTNAME}\";/" \
  "$VARS_FILE"
sed -i \
  "s|configRoot = \"[^\"]*\";|configRoot = \"/home/${NIXOS_USER}/nixos-config\";|" \
  "$VARS_FILE"

log "fixing ownership..."
# 不使用硬编码 UID，而是在 activation script 中由系统自动处理
# 这里只设置一个合理的默认值（首个普通用户通常是 1000）
# 真正的权限修复会在首次启动时由 NixOS 的 user activation 处理
owner_group="users"
if ! getent group "$owner_group" >/dev/null 2>&1; then
  owner_group="$DEFAULT_GID_FALLBACK"
fi
chown -R "$DEFAULT_UID":"$owner_group" "$USER_HOME" || true

log "writing hashed passwords..."
mkdir -p /mnt/persistent/etc

# 生成密码哈希（用于普通用户和 root）
if [[ "$HASH_CMD" == "mkpasswd" ]]; then
  HASHED_PASSWORD=$(printf '%s' "$NIXOS_PASSWORD" | mkpasswd -m sha-512 -s | tr -d '\n')
else
  HASHED_PASSWORD=$(printf '%s' "$NIXOS_PASSWORD" | openssl passwd -6 -stdin | tr -d '\n')
fi

# 写入用户密码文件
USER_PASSWORD_FILE="/mnt/persistent/etc/user-password"
printf '%s' "$HASHED_PASSWORD" > "$USER_PASSWORD_FILE"
chmod "$PASSWORD_FILE_MODE" "$USER_PASSWORD_FILE"

# 写入 root 密码文件（使用相同密码用于紧急恢复）
ROOT_PASSWORD_FILE="/mnt/persistent/etc/root-password"
printf '%s' "$HASHED_PASSWORD" > "$ROOT_PASSWORD_FILE"
chmod "$PASSWORD_FILE_MODE" "$ROOT_PASSWORD_FILE"

log "installing NixOS..."
cd "$CONFIG_DEST"
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
