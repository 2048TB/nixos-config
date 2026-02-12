#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -h "$SCRIPT_PATH" ]]; do
  SCRIPT_LINK_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd -P)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  if [[ "$SCRIPT_PATH" != /* ]]; then
    SCRIPT_PATH="${SCRIPT_LINK_DIR}/${SCRIPT_PATH}"
  fi
done
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd -P)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
HOST="zly"
FLAKE="${REPO_ROOT}"
DRY_RUN="${DRY_RUN:-0}"
CONFIRM="${CONFIRM:-1}"
NIXOS_DISK_DEVICE="${NIXOS_DISK_DEVICE:-}"
LUKS_DEVICE=""
DISK_DEVICE=""
DISK_CANDIDATES=()

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-live.sh

This script is fully automated:
  1) auto-detect and pick the largest non-USB disk
  2) run disko
  3) check EFI mountpoint
  4) interactively change LUKS password
  5) run nixos-install
  (can be run from any current working directory)

Environment variables:
  DRY_RUN=1         Print commands without executing
  CONFIRM=0         Skip confirmation before destructive steps (default: confirm)
  NIXOS_DISK_DEVICE=/dev/sdX  Use explicit target disk (overrides auto-selection)

Help:
  ./scripts/install-live.sh --help
EOF
}

die_with_usage() {
  echo "ERROR: $*" >&2
  echo >&2
  usage >&2
  exit 1
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

run_root() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ "$EUID" -eq 0 ]]; then
      printf '+ '
    else
      printf '+ sudo '
    fi
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi

  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

preflight_cleanup() {
  # 尽量释放旧挂载/加密设备，避免分区表无法更新
  run_root swapoff -a 2>/dev/null || echo "WARN: swapoff failed (may be inactive)" >&2
  run_root umount -R /mnt 2>/dev/null || echo "WARN: umount /mnt failed (may not be mounted)" >&2
  run_root umount -R /boot 2>/dev/null || echo "WARN: umount /boot failed (may not be mounted)" >&2
  run_root cryptsetup luksClose crypted-nixos 2>/dev/null || echo "WARN: luksClose failed (may not be open)" >&2
  run_root partprobe "$DISK_DEVICE" || echo "WARN: partprobe failed on $DISK_DEVICE" >&2
  run_root udevadm settle || echo "WARN: udevadm settle failed" >&2
}

check_disko_result() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: skipping disko result checks."
    return 0
  fi

  local esp="/dev/disk/by-partlabel/ESP"
  local luks="/dev/disk/by-partlabel/NIXOS-CRYPT"
  local required_mounts=("${TARGET_EFI_MOUNTPOINT}" "/mnt/nix" "/mnt/persistent")

  if [[ ! -e "$esp" || ! -e "$luks" ]]; then
    echo "ERROR: disko did not create expected partition labels:" >&2
    echo "  missing: $( [[ -e "$esp" ]] || echo "$esp" ) $( [[ -e "$luks" ]] || echo "$luks" )" >&2
    echo "Hint: device is likely still in use. Reboot the ISO and retry." >&2
    return 1
  fi

  if ! findmnt -rn -o TARGET | grep -Eq '^/mnt(/|$)'; then
    echo "ERROR: no mountpoints exist under /mnt after disko." >&2
    echo "Hint: disko may not have mounted filesystems correctly." >&2
    return 1
  fi

  for mountpoint in "${required_mounts[@]}"; do
    if ! run_root findmnt "$mountpoint" >/dev/null 2>&1; then
      echo "ERROR: required mountpoint ${mountpoint} is not mounted after disko." >&2
      echo "Hint: check disko layout and mountpoints in nix/hosts/${HOST}.nix." >&2
      return 1
    fi
  done

  run_root findmnt -R /mnt || true
}

detect_disk_candidates() {
  mapfile -t DISK_CANDIDATES < <(
    lsblk -dn -b -o NAME,TYPE,RM,SIZE,TRAN,MODEL | awk '
      $2 == "disk" && $3 == "0" && $1 ~ /^(sd|vd|xvd|nvme|mmcblk)/ && $5 != "usb" {
        name = $1
        size = $4
        tran = $5
        $1 = $2 = $3 = $4 = $5 = ""
        sub(/^ +/, "", $0)
        model = ($0 == "" ? "-" : $0)
        printf "/dev/%s|%s|%s|%s\n", name, size, tran, model
      }
    '
  )
}

select_disk_device() {
  detect_disk_candidates

  if [[ "${#DISK_CANDIDATES[@]}" -eq 0 ]]; then
    die "No eligible non-USB disk detected via lsblk."
  fi

  if [[ -n "$NIXOS_DISK_DEVICE" ]]; then
    local found=0
    for idx in "${!DISK_CANDIDATES[@]}"; do
      IFS='|' read -r path _size _tran _model <<<"${DISK_CANDIDATES[$idx]}"
      if [[ "$path" == "$NIXOS_DISK_DEVICE" ]]; then
        DISK_DEVICE="$path"
        found=1
        break
      fi
    done
    if [[ "$found" -eq 0 ]]; then
      die "NIXOS_DISK_DEVICE ${NIXOS_DISK_DEVICE} is not an eligible non-USB disk."
    fi
    return 0
  fi

  # Automatically pick the largest disk by byte size.
  local max_size=-1
  local chosen_index=0
  for idx in "${!DISK_CANDIDATES[@]}"; do
    IFS='|' read -r _path size_bytes _tran _model <<<"${DISK_CANDIDATES[$idx]}"
    if (( size_bytes > max_size )); then
      max_size="${size_bytes}"
      chosen_index="${idx}"
    fi
  done
  IFS='|' read -r DISK_DEVICE _ _ _ <<<"${DISK_CANDIDATES[$chosen_index]}"

  echo "Detected candidate disks (auto-select largest non-USB):"
  for idx in "${!DISK_CANDIDATES[@]}"; do
    IFS='|' read -r path size_bytes tran model <<<"${DISK_CANDIDATES[$idx]}"
    size_human="$(numfmt --to=iec-i --suffix=B "${size_bytes}" 2>/dev/null || echo "${size_bytes}")"
    marker=" "
    if [[ "$idx" -eq "$chosen_index" ]]; then
      marker="*"
    fi
    echo " ${marker} ${path} (${size_human}, tran=${tran:-unknown}, ${model})"
  done
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  die_with_usage "This script is automated and does not accept CLI options."
fi

if [[ "$DRY_RUN" != "0" && "$DRY_RUN" != "1" ]]; then
  die "DRY_RUN must be 0 or 1."
fi
if [[ "$CONFIRM" != "0" && "$CONFIRM" != "1" ]]; then
  die "CONFIRM must be 0 or 1."
fi

FLAKE_REF="${FLAKE}#${HOST}"
select_disk_device

EFI_SYS_MOUNTPOINT="/boot"
TARGET_EFI_MOUNTPOINT="/mnt${EFI_SYS_MOUNTPOINT}"

if [[ -z "$LUKS_DEVICE" ]]; then
  LUKS_DEVICE="/dev/disk/by-partlabel/NIXOS-CRYPT"
fi

DISKO_MODE="disko"
TOTAL_STEPS=7
STEP=1

echo "Target flake: ${FLAKE_REF}"
echo "Disk mode: ${DISKO_MODE}"
echo "Expected EFI mountpoint: ${TARGET_EFI_MOUNTPOINT}"
echo "WARNING: This mode may destroy existing partition tables and data."
echo "LUKS password change: enabled (${LUKS_DEVICE})"
echo "Disk device: ${DISK_DEVICE}"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: using default EFI/LUKS paths."
fi
if [[ "$CONFIRM" -eq 1 ]]; then
  echo
  echo "About to wipe and re-partition: ${DISK_DEVICE}"
  read -r -p "Type YES to continue: " confirm
  if [[ "$confirm" != "YES" ]]; then
    die "Confirmation not received. Aborting."
  fi
fi

echo
echo "[${STEP}/${TOTAL_STEPS}] Pre-cleaning mounts/LUKS..."
preflight_cleanup
STEP=$((STEP + 1))

echo
echo "[${STEP}/${TOTAL_STEPS}] Running disko..."
DISKO_REV="$(jq -r '.nodes.disko.locked.rev' "${FLAKE}/flake.lock")"
run_root env NIXOS_DISK_DEVICE="$DISK_DEVICE" \
  nix --extra-experimental-features nix-command --extra-experimental-features flakes \
  run --impure "github:nix-community/disko/${DISKO_REV}" -- --mode "$DISKO_MODE" --flake "$FLAKE_REF"
check_disko_result
STEP=$((STEP + 1))

echo
echo "[${STEP}/${TOTAL_STEPS}] Checking EFI mountpoint ${TARGET_EFI_MOUNTPOINT}..."
if [[ "$DRY_RUN" -eq 1 ]]; then
  run_root findmnt "$TARGET_EFI_MOUNTPOINT"
else
  if ! run_root findmnt "$TARGET_EFI_MOUNTPOINT" >/dev/null; then
    echo "ERROR: ${TARGET_EFI_MOUNTPOINT} is not mounted. Stop before nixos-install." >&2
    exit 1
  fi
fi
STEP=$((STEP + 1))

echo
echo "[${STEP}/${TOTAL_STEPS}] Interactively setting LUKS password..."
if [[ "$DRY_RUN" -eq 1 ]]; then
  run_root cryptsetup luksChangeKey "$LUKS_DEVICE"
else
  if ! run_root cryptsetup isLuks "$LUKS_DEVICE" >/dev/null 2>&1; then
    echo "ERROR: ${LUKS_DEVICE} is not a LUKS device." >&2
    exit 1
  fi
  run_root cryptsetup luksChangeKey "$LUKS_DEVICE"
fi
STEP=$((STEP + 1))

echo
echo "[${STEP}/${TOTAL_STEPS}] Installing NixOS..."
run_root env NIXOS_DISK_DEVICE="$DISK_DEVICE" nixos-install --impure --flake "$FLAKE_REF"
STEP=$((STEP + 1))

echo
echo "[${STEP}/${TOTAL_STEPS}] Syncing flake into target /persistent/nixos-config..."
TARGET_FLAKE_DIR="/mnt/persistent/nixos-config"
if ! run_root findmnt /mnt/persistent >/dev/null 2>&1; then
  die "/mnt/persistent is not mounted. Refusing to sync flake."
fi
TARGET_FLAKE_TMP="${TARGET_FLAKE_DIR}.tmp.$$"
run_root rm -rf "$TARGET_FLAKE_TMP"
run_root cp -a "${REPO_ROOT}/." "$TARGET_FLAKE_TMP/"
# 使用目标系统的用户 UID:GID（而非 live ISO 的，避免安装后权限不正确）
if run_root test -f /mnt/etc/passwd; then
  TARGET_OWNER="$(run_root awk -F: '$3 >= 1000 && $3 < 60000 {print $3":"$4; exit}' /mnt/etc/passwd)"
fi
run_root chown -R "${TARGET_OWNER:-1000:100}" "$TARGET_FLAKE_TMP"
# 原子替换：先复制到临时目录，再 mv 替换，避免中途失败导致目标不完整
run_root rm -rf "$TARGET_FLAKE_DIR"
run_root mv "$TARGET_FLAKE_TMP" "$TARGET_FLAKE_DIR"

# 清理历史 Provider app 设置，避免旧 lockdown/auto-connect 状态导致新系统首启无网
run_root rm -f /mnt/persistent/etc/provider-app-vpn/settings.json

run_root rm -rf /mnt/etc/nixos
run_root ln -sfn /persistent/nixos-config /mnt/etc/nixos
STEP=$((STEP + 1))
echo
echo "[${STEP}/${TOTAL_STEPS}] Verifying flake (dry-build)..."
run_root nixos-rebuild dry-build --flake /mnt/persistent/nixos-config#${HOST}

echo
echo "Install finished."
echo "Next step after reboot:"
echo "  sudo nixos-rebuild switch --flake /etc/nixos#${HOST}"
