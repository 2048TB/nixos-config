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

is_mounted() {
  local mount_point="$1"
  grep -qs " ${mount_point} " /proc/mounts
}

require_mounted() {
  local mount_point="$1"
  if ! is_mounted "$mount_point"; then
    fail "mount not found: $mount_point"
  fi
}

require_file() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    fail "missing file: $file_path"
  fi
}

require_nonempty() {
  local file_path="$1"
  if [[ ! -s "$file_path" ]]; then
    fail "empty file: $file_path"
  fi
}

require_file_mode() {
  local file_path="$1"
  local expected_mode="$2"
  local actual_mode
  actual_mode="$(stat -c %a "$file_path" 2>/dev/null || echo "")"
  if [[ "$actual_mode" != "$expected_mode" ]]; then
    fail "bad permissions on $file_path (expected $expected_mode, got ${actual_mode:-unknown})"
  fi
}

require_grep() {
  local pattern="$1"
  local file_path="$2"
  if ! grep -q "$pattern" "$file_path" 2>/dev/null; then
    fail "pattern not found in $file_path: $pattern"
  fi
}

disk_has_data() {
  local disk="$1"

  # 如果存在子设备（分区/加密/LVM），认为磁盘非空
  if lsblk -rno TYPE "$disk" 2>/dev/null | grep -qv '^disk$'; then
    return 0
  fi

  # 如果磁盘本身有文件系统签名，也认为非空
  if lsblk -rno FSTYPE "$disk" 2>/dev/null | grep -qv '^$'; then
    return 0
  fi

  # 进一步用 wipefs 检测签名（若可用）
  if command -v wipefs >/dev/null 2>&1; then
    if wipefs -n "$disk" 2>/dev/null | grep -q .; then
      return 0
    fi
  fi

  return 1
}

validate_gpu_choice() {
  local choice="$1"
  case "$choice" in
    none|amd|amdgpu|nvidia|amd-nvidia-hybrid) return 0 ;;
    *) fail "Invalid GPU mode: $choice (use: none|amd|amdgpu|nvidia|amd-nvidia-hybrid)" ;;
  esac
}

verify_install_state() {
  log "verifying install state..."

  # 挂载点
  local mounts=(
    "/mnt"
    "/mnt/boot"
    "/mnt/nix"
    "/mnt/home"
    "/mnt/persistent"
    "/mnt/swap"
  )
  local mount_point
  for mount_point in "${mounts[@]}"; do
    require_mounted "$mount_point"
  done

  # 交换文件
  require_file "/mnt/swap/swapfile"

  # 密码文件（持久化 + 复制到 /etc）
  local password_files=(
    "/mnt/persistent/etc/user-password"
    "/mnt/persistent/etc/root-password"
    "/mnt/etc/user-password"
    "/mnt/etc/root-password"
  )
  local password_file
  for password_file in "${password_files[@]}"; do
    require_file "$password_file"
    require_file_mode "$password_file" "600"
  done

  # 配置目录完整性
  local config_files=(
    "${CONFIG_DEST}/flake.nix"
    "${CONFIG_DEST}/nix/vars/default.nix"
    "${CONFIG_DEST}/nix/vars/detected-gpu.txt"
    "${CONFIG_DEST}/nix/hosts/${NIXOS_HOSTNAME}.nix"
    "${CONFIG_DEST}/nix/hosts/${NIXOS_HOSTNAME}-hardware.nix"
  )
  local config_file
  for config_file in "${config_files[@]}"; do
    require_file "$config_file"
  done
  require_nonempty "${CONFIG_DEST}/nix/vars/detected-gpu.txt"

  # 确保生成的硬件配置中声明了 /persistent
  require_grep 'fileSystems.\"/persistent\"' "${CONFIG_DEST}/nix/hosts/${NIXOS_HOSTNAME}-hardware.nix"

  # 确保变量已更新
  require_grep "username = \"${NIXOS_USER}\";" "${CONFIG_DEST}/nix/vars/default.nix"
  require_grep "hostname = \"${NIXOS_HOSTNAME}\";" "${CONFIG_DEST}/nix/vars/default.nix"
  require_grep "configRoot = \"/home/${NIXOS_USER}/nixos-config\";" "${CONFIG_DEST}/nix/vars/default.nix"
}

# 清理函数：在脚本退出时自动执行
cleanup() {
  if [[ "${CLEANUP_NEEDED:-0}" == "1" ]]; then
    log "Cleaning up mounts and LUKS..."
    # 先关闭交换文件，避免卸载失败
    swapoff /mnt/swap/swapfile 2>/dev/null || true
    umount -R /mnt 2>/dev/null || true
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

# 优先使用 curl（安装 ISO 中通常有）
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

# 检查密码哈希工具（优先使用 mkpasswd，回退到 openssl）
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

if [[ -z "${NIXOS_PASSWORD}" ]]; then
  fail "password cannot be empty"
fi

if [[ -z "${NIXOS_LUKS_PASSWORD:-}" ]]; then
  NIXOS_LUKS_PASSWORD="$NIXOS_PASSWORD"
fi

if [[ -z "${NIXOS_LUKS_PASSWORD}" ]]; then
  fail "LUKS password cannot be empty"
fi

if [[ -z "${NIXOS_DISK:-}" ]]; then
  # 尝试检测各种类型的磁盘（NVMe、SATA、虚拟机）
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
if disk_has_data "$NIXOS_DISK" && [[ "${FORCE:-0}" != "1" ]]; then
  log "WARNING: Disk $NIXOS_DISK appears to have existing partitions or filesystems:"
  lsblk -f "$NIXOS_DISK" || true
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
if [[ ! "$NIXOS_HOSTNAME" =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]]; then
  fail "Invalid hostname: $NIXOS_HOSTNAME (use lowercase letters, digits, hyphen; max 63 chars)"
fi

if [[ -z "${NIXOS_GPU:-}" ]]; then
  while true; do
    echo "Select GPU mode:"
    echo "  1) none"
    echo "  2) amd"
    echo "  3) nvidia"
    echo "  4) amd-nvidia-hybrid"
    read -r -p "Choice [1-4]: " gpu_choice
    case "$gpu_choice" in
      1) NIXOS_GPU="none"; break ;;
      2) NIXOS_GPU="amd"; break ;;
      3) NIXOS_GPU="nvidia"; break ;;
      4) NIXOS_GPU="amd-nvidia-hybrid"; break ;;
      *) log "Invalid choice, please select 1, 2, 3, or 4." ;;
    esac
  done
else
  NIXOS_GPU="$(printf '%s' "$NIXOS_GPU" | tr 'A-Z' 'a-z')"
  validate_gpu_choice "$NIXOS_GPU"
fi

SWAP_GB="${NIXOS_SWAP_SIZE_GB:-$DEFAULT_SWAP_GB}"
if [[ ! "$SWAP_GB" =~ ^[1-9][0-9]*$ ]]; then
  fail "Invalid swap size: ${SWAP_GB} (must be a positive integer, GB)"
fi

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
parted -s "$NIXOS_DISK" name 1 ESP
parted -s "$NIXOS_DISK" name 2 NIXOS-CRYPT

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
mount -o "subvol=@swap,noatime,nodatacow,compress=no" /dev/mapper/crypted-nixos /mnt/swap
mount "$ESP" /mnt/boot
# 注意：@snapshots 和 @tmp 仅创建子卷备用，安装时不挂载
# - @snapshots: 预留用于 Btrfs 快照功能
# - @tmp: 系统使用内存 tmpfs（性能更优）

log "creating swapfile..."
btrfs filesystem mkswapfile --size "${SWAP_GB}g" --uuid clear /mnt/swap/swapfile

# 验证交换文件创建成功
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

# 使用 tar 管道复制（不依赖 git/rsync 工具）
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

# 如果自定义主机名，则创建对应的主机配置与硬件文件
if [[ "$NIXOS_HOSTNAME" != "nixos-config" ]]; then
  HOSTS_DIR="${CONFIG_DEST}/nix/hosts"
  DEFAULT_HOST_FILE="${HOSTS_DIR}/nixos-config.nix"
  DEFAULT_HW_FILE="${HOSTS_DIR}/nixos-config-hardware.nix"
  CUSTOM_HOST_FILE="${HOSTS_DIR}/${NIXOS_HOSTNAME}.nix"
  CUSTOM_HW_FILE="${HOSTS_DIR}/${NIXOS_HOSTNAME}-hardware.nix"

  if [[ -f "$DEFAULT_HOST_FILE" ]]; then
    cp -f "$DEFAULT_HOST_FILE" "$CUSTOM_HOST_FILE"
    # 更新硬件配置引用
    sed -i "s|./nixos-config-hardware.nix|./${NIXOS_HOSTNAME}-hardware.nix|" "$CUSTOM_HOST_FILE"
  else
    fail "missing host template: $DEFAULT_HOST_FILE"
  fi

  cp -f "$DEFAULT_HW_FILE" "$CUSTOM_HW_FILE"
fi

log "writing gpu choice..."
printf '%s\n' "$NIXOS_GPU" \
  > "${CONFIG_DEST}/nix/vars/detected-gpu.txt"

log "updating nix/vars/default.nix..."
VARS_FILE="${CONFIG_DEST}/nix/vars/default.nix"
sed -i \
  -e "s/username = \"[^\"]*\";/username = \"${NIXOS_USER}\";/" \
  -e "s/hostname = \"[^\"]*\";/hostname = \"${NIXOS_HOSTNAME}\";/" \
  -e "s|configRoot = \"[^\"]*\";|configRoot = \"/home/${NIXOS_USER}/nixos-config\";|" \
  "$VARS_FILE"

log "fixing ownership..."
# 不使用硬编码 UID，而是在激活脚本中由系统自动处理
# 这里只设置一个合理的默认值（首个普通用户通常是 1000）
# 真正的权限修复会在首次启动时由 NixOS 的用户激活阶段处理
owner_group="users"
if ! getent group "$owner_group" >/dev/null 2>&1; then
  owner_group="$DEFAULT_GID_FALLBACK"
fi
chown -R "$DEFAULT_UID":"$owner_group" "$USER_HOME" || true

log "writing hashed passwords..."
mkdir -p /mnt/persistent/etc

# 生成密码哈希（用于普通用户和 root 账户）
if [[ "$HASH_CMD" == "mkpasswd" ]]; then
  HASHED_PASSWORD=$(printf '%s' "$NIXOS_PASSWORD" | mkpasswd -m sha-512 -s | tr -d '\n')
else
  HASHED_PASSWORD=$(printf '%s' "$NIXOS_PASSWORD" | openssl passwd -6 -stdin | tr -d '\n')
fi

# 写入用户密码文件
USER_PASSWORD_FILE="/mnt/persistent/etc/user-password"
printf '%s' "$HASHED_PASSWORD" > "$USER_PASSWORD_FILE"
chmod "$PASSWORD_FILE_MODE" "$USER_PASSWORD_FILE"

# 写入 root 账户密码文件（与用户密码相同）
ROOT_PASSWORD_FILE="/mnt/persistent/etc/root-password"
printf '%s' "$HASHED_PASSWORD" > "$ROOT_PASSWORD_FILE"
chmod "$PASSWORD_FILE_MODE" "$ROOT_PASSWORD_FILE"

# 安装阶段需要 /etc/user-password 与 /etc/root-password 可读
log "staging password files into /etc..."
mkdir -p /mnt/etc
cp -f "$USER_PASSWORD_FILE" /mnt/etc/user-password
cp -f "$ROOT_PASSWORD_FILE" /mnt/etc/root-password
chmod "$PASSWORD_FILE_MODE" /mnt/etc/user-password /mnt/etc/root-password

verify_install_state

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
