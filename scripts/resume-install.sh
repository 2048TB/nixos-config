#!/usr/bin/env bash
set -euo pipefail

# NixOS 恢复安装脚本
#
# 用于在 auto-install.sh 失败后恢复继续安装
# 前提：磁盘已分区、LUKS 已创建、配置已复制
#
# 使用方式：
#   sudo bash resume-install.sh
#
# 或指定参数：
#   NIXOS_DISK=/dev/nvme0n1 NIXOS_USER=myuser NIXOS_GPU=nvidia sudo -E bash resume-install.sh

# 配置常量（与 auto-install.sh 保持一致）
readonly BTRFS_OPTS_COMPRESS="compress-force=zstd:1"
readonly BTRFS_OPTS_NOATIME="noatime"

log() {
  echo "[resume-install] $*"
}

fail() {
  echo "[resume-install] ERROR: $*" >&2
  exit 1
}

if [[ $(id -u) -ne 0 ]]; then
  fail "please run as root"
fi

# 检测或询问磁盘
if [[ -z "${NIXOS_DISK:-}" ]]; then
  log "Detecting disk..."
  mapfile -t all_disks < <(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}' | grep -E 'nvme[0-9]+n1$|sd[a-z]$|vd[a-z]$|xvd[a-z]$' || true)

  if [[ ${#all_disks[@]} -eq 1 ]]; then
    NIXOS_DISK="${all_disks[0]}"
    log "Auto-detected disk: $NIXOS_DISK"
  else
    log "Available disks:"
    lsblk -d -o NAME,TYPE,SIZE,MODEL,TRAN
    echo ""
    read -r -p "Enter disk path (e.g., /dev/nvme0n1): " NIXOS_DISK
  fi
fi

if [[ ! -b "$NIXOS_DISK" ]]; then
  fail "disk not found: $NIXOS_DISK"
fi

# 检测分区后缀
part_suffix=""
if [[ "$NIXOS_DISK" =~ [0-9]$ ]]; then
  part_suffix="p"
fi

ESP="${NIXOS_DISK}${part_suffix}1"
ROOT="${NIXOS_DISK}${part_suffix}2"

# 验证分区存在
if [[ ! -b "$ESP" ]] || [[ ! -b "$ROOT" ]]; then
  fail "partitions not found. Expected: $ESP and $ROOT"
fi

log "Using disk: $NIXOS_DISK"
log "  ESP: $ESP"
log "  ROOT: $ROOT"

# 检查 LUKS 是否已打开
if [[ -b /dev/mapper/crypted-nixos ]]; then
  log "LUKS already open: /dev/mapper/crypted-nixos"
else
  log "Opening LUKS container..."
  if ! cryptsetup luksOpen "$ROOT" crypted-nixos; then
    fail "failed to open LUKS. Wrong password?"
  fi
fi

# 检查是否已挂载
if mountpoint -q /mnt; then
  log "WARNING: /mnt already mounted. Unmounting first..."
  if ! umount -R /mnt 2>/dev/null; then
    log "Failed to unmount /mnt. Trying to continue anyway..."
  fi
fi

# 挂载根文件系统
log "Mounting root filesystem..."
mount -o "subvol=@root,${BTRFS_OPTS_COMPRESS},${BTRFS_OPTS_NOATIME}" /dev/mapper/crypted-nixos /mnt || fail "failed to mount root"

# 创建挂载点
log "Creating mount points..."
mkdir -p /mnt/{nix,persistent,snapshots,tmp,swap,boot}

# 挂载所有子卷
log "Mounting subvolumes..."
mount -o "subvol=@nix,${BTRFS_OPTS_COMPRESS},${BTRFS_OPTS_NOATIME}" /dev/mapper/crypted-nixos /mnt/nix || fail "failed to mount /nix"
mount -o "subvol=@persistent,${BTRFS_OPTS_COMPRESS}" /dev/mapper/crypted-nixos /mnt/persistent || fail "failed to mount /persistent"
mount -o "subvol=@snapshots,${BTRFS_OPTS_COMPRESS},${BTRFS_OPTS_NOATIME}" /dev/mapper/crypted-nixos /mnt/snapshots || fail "failed to mount /snapshots"
mount -o "subvol=@tmp,${BTRFS_OPTS_COMPRESS}" /dev/mapper/crypted-nixos /mnt/tmp || fail "failed to mount /tmp"
mount -o subvol=@swap /dev/mapper/crypted-nixos /mnt/swap || fail "failed to mount /swap"

# 挂载 ESP
log "Mounting ESP..."
mount "$ESP" /mnt/boot || fail "failed to mount ESP"

# 启用 swap
log "Enabling swap..."
if [[ -f /mnt/swap/swapfile ]]; then
  if ! swapon /mnt/swap/swapfile 2>/dev/null; then
    log "WARNING: swap already enabled or failed to enable"
  fi
else
  fail "swapfile not found at /mnt/swap/swapfile"
fi

# 验证挂载
log "Verifying mounts..."
if ! mountpoint -q /mnt; then
  fail "root filesystem not mounted correctly"
fi
if ! mountpoint -q /mnt/boot; then
  fail "ESP not mounted correctly"
fi

log "All filesystems mounted successfully!"
log ""

# 查找配置目录
log "Looking for configuration..."
if [[ -z "${NIXOS_USER:-}" ]]; then
  # 尝试自动检测用户目录
  user_dirs=(/mnt/persistent/home/*)
  if [[ ${#user_dirs[@]} -eq 1 ]] && [[ -d "${user_dirs[0]}" ]]; then
    NIXOS_USER=$(basename "${user_dirs[0]}")
    log "Auto-detected user: $NIXOS_USER"
  else
    log "Available users in /persistent/home/:"
    ls -1 /mnt/persistent/home/ 2>/dev/null || echo "  (none found)"
    echo ""
    read -r -p "Enter username: " NIXOS_USER
  fi
fi

CONFIG_DIR="/mnt/persistent/home/${NIXOS_USER}/nixos-config"

if [[ ! -d "$CONFIG_DIR" ]]; then
  fail "configuration not found at: $CONFIG_DIR"
fi

log "Found configuration at: $CONFIG_DIR"

# 进入配置目录
cd "$CONFIG_DIR" || fail "failed to cd to $CONFIG_DIR"

# 检查是否是 git 仓库
if [[ -d .git ]]; then
  log "Updating configuration from GitHub..."

  # 显示当前 commit
  current_commit=$(git log --oneline -1 2>/dev/null || echo "unknown")
  log "Current commit: $current_commit"

  # 尝试更新
  if git fetch origin 2>/dev/null; then
    log "Fetched latest from origin"

    # 显示可用更新
    commits_behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")
    if [[ "$commits_behind" -gt 0 ]]; then
      log "Configuration is $commits_behind commit(s) behind origin/main"
      log "New commits:"
      git log --oneline HEAD..origin/main | head -5 | sed 's/^/  /'
      echo ""
      read -r -p "Pull latest changes? [Y/n] " pull_confirm
      if [[ ! "$pull_confirm" =~ ^[Nn]$ ]]; then
        git reset --hard origin/main || log "WARNING: failed to update. Continuing with current version..."
        log "Updated to: $(git log --oneline -1)"
      fi
    else
      log "Configuration is already up-to-date"
    fi
  else
    log "WARNING: failed to fetch from GitHub. Continuing with existing configuration..."
  fi
else
  log "WARNING: not a git repository. Using existing configuration as-is"
fi

log ""

# 询问 GPU 类型
if [[ -z "${NIXOS_GPU:-}" ]]; then
  # 尝试从配置文件读取
  if [[ -f "nix/vars/detected-gpu.txt" ]]; then
    detected_gpu=$(cat "nix/vars/detected-gpu.txt" 2>/dev/null || echo "")
    if [[ -n "$detected_gpu" ]]; then
      log "Detected GPU from config: $detected_gpu"
      read -r -p "Use this GPU type? [Y/n] " gpu_confirm
      if [[ ! "$gpu_confirm" =~ ^[Nn]$ ]]; then
        NIXOS_GPU="$detected_gpu"
      fi
    fi
  fi

  # 如果仍未设置，询问用户
  if [[ -z "${NIXOS_GPU:-}" ]]; then
    log "GPU options:"
    log "  nvidia - NVIDIA GPU"
    log "  amd    - AMD GPU"
    log "  none   - Intel/Generic (modesetting driver)"
    echo ""
    read -r -p "Enter GPU type [nvidia/amd/none]: " NIXOS_GPU
  fi
fi

# 验证 GPU 选项
if [[ ! "$NIXOS_GPU" =~ ^(nvidia|amd|none)$ ]]; then
  log "WARNING: invalid GPU type: $NIXOS_GPU. Using 'none'"
  NIXOS_GPU="none"
fi

log "GPU type: $NIXOS_GPU"
log ""

# 询问主机名
if [[ -z "${NIXOS_HOSTNAME:-}" ]]; then
  # 尝试从配置文件读取
  if [[ -f "nix/vars/default.nix" ]]; then
    detected_hostname=$(grep -oP 'hostname\s*=\s*"\K[^"]+' "nix/vars/default.nix" 2>/dev/null || echo "")
    if [[ -n "$detected_hostname" ]]; then
      log "Detected hostname from config: $detected_hostname"
      NIXOS_HOSTNAME="$detected_hostname"
    fi
  fi

  if [[ -z "${NIXOS_HOSTNAME:-}" ]]; then
    NIXOS_HOSTNAME="nixos-config"
  fi
fi

log "Hostname: $NIXOS_HOSTNAME"
log ""

# 显示安装摘要
log "========================================="
log "Ready to continue installation"
log "========================================="
log "  Disk:     $NIXOS_DISK"
log "  User:     $NIXOS_USER"
log "  Hostname: $NIXOS_HOSTNAME"
log "  GPU:      $NIXOS_GPU"
log "  Config:   $CONFIG_DIR"
log "========================================="
log ""
read -r -p "Continue with installation? [Y/n] " install_confirm
if [[ "$install_confirm" =~ ^[Nn]$ ]]; then
  log "Installation cancelled"
  exit 0
fi

log ""
log "Starting nixos-install..."
log "This will take 10-20 minutes (downloading from binary cache)..."
log ""

# 执行安装
if NIXOS_GPU="$NIXOS_GPU" nixos-install --impure --flake ".#${NIXOS_HOSTNAME}"; then
  log ""
  log "========================================="
  log "Installation completed successfully!"
  log "========================================="
  log ""
  log "Next steps:"
  log "  1. Reboot: sudo reboot"
  log "  2. Login with user: $NIXOS_USER"
  log "  3. Update if needed: cd ~/nixos-config && sudo nixos-rebuild switch --flake .#${NIXOS_HOSTNAME}"
  log ""

  # 询问是否重启
  read -r -p "Reboot now? [y/N] " reboot_confirm
  if [[ "$reboot_confirm" =~ ^[Yy]$ ]]; then
    log "Rebooting..."
    reboot
  fi
else
  log ""
  log "========================================="
  log "Installation FAILED"
  log "========================================="
  log ""
  log "Possible issues:"
  log "  1. Configuration errors - check output above"
  log "  2. Network issues - ensure internet connection"
  log "  3. Binary cache unavailable - some packages may need building"
  log ""
  log "Filesystems remain mounted at /mnt for investigation"
  log "Run 'nix flake check --impure' to validate configuration"
  log ""
  exit 1
fi
