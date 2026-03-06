#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

usage() {
  cat <<'EOF'
usage:
  new-host.sh <nixos|darwin> <host-name> [--from <source-host>] [--gpu-mode <mode>] [--repo <repo>] [--dry-run] [--force]

examples:
  new-host.sh nixos zbook --from zly
  new-host.sh nixos zbook --gpu-mode amd-nvidia-hybrid
  new-host.sh darwin mbp14 --from zly-mac
  new-host.sh nixos devbox --dry-run
EOF
}

escape_sed_pattern() {
  # shellcheck disable=SC2016
  printf '%s' "$1" | sed -e 's/[\/&.[\*^$()+?{}|]/\\&/g'
}

platform="${1:-}"
host_name="${2:-}"
shift "$(( $# >= 2 ? 2 : $# ))"

source_host=""
gpu_mode=""
repo="${NIXOS_CONFIG_REPO:-$PWD}"
dry_run=0
force=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --from)
      source_host="${2:-}"
      shift 2
      ;;
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --gpu-mode)
      gpu_mode="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --force)
      force=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$platform" ] || [ -z "$host_name" ]; then
  usage >&2
  exit 2
fi

is_valid_gpu_mode() {
  local mode="${1:-}"
  case "$mode" in
    auto|none|amd|amdgpu|nvidia|nvidia-prime|modesetting|amd-nvidia-hybrid)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

pci_slot_to_bus_id() {
  local slot="${1:-}"
  local bus_hex dev_hex func
  if [[ "$slot" =~ ^([0-9A-Fa-f]{4}:)?([0-9A-Fa-f]{2}):([0-9A-Fa-f]{2})\.([0-7])$ ]]; then
    bus_hex="${BASH_REMATCH[2]}"
    dev_hex="${BASH_REMATCH[3]}"
    func="${BASH_REMATCH[4]}"
    printf 'PCI:%d:%d:%d\n' "$((16#$bus_hex))" "$((16#$dev_hex))" "$func"
    return 0
  fi
  return 1
}

detected_gpu_mode=""
detected_intel_bus_id=""
detected_amdgpu_bus_id=""
detected_nvidia_bus_id=""

detect_gpu_settings() {
  local has_nvidia=0
  local has_amd=0
  local has_intel=0
  local line="" slot="" bus_id="" lower=""

  if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt -q; then
    detected_gpu_mode="modesetting"
    return 0
  fi

  if ! command -v lspci >/dev/null 2>&1; then
    return 0
  fi

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    slot="${line%% *}"
    bus_id="$(pci_slot_to_bus_id "$slot" || true)"
    lower="$(printf '%s\n' "$line" | tr '[:upper:]' '[:lower:]')"

    if [[ "$lower" == *nvidia* ]]; then
      has_nvidia=1
      if [ -z "$detected_nvidia_bus_id" ] && [ -n "$bus_id" ]; then
        detected_nvidia_bus_id="$bus_id"
      fi
    elif [[ "$lower" == *amd* || "$lower" == *ati* || "$lower" == *"advanced micro devices"* ]]; then
      has_amd=1
      if [ -z "$detected_amdgpu_bus_id" ] && [ -n "$bus_id" ]; then
        detected_amdgpu_bus_id="$bus_id"
      fi
    elif [[ "$lower" == *intel* ]]; then
      has_intel=1
      if [ -z "$detected_intel_bus_id" ] && [ -n "$bus_id" ]; then
        detected_intel_bus_id="$bus_id"
      fi
    fi
  done < <(lspci -D | grep -Ei 'vga|3d|display' || true)

  if [ "$has_nvidia" -eq 1 ] && [ "$has_amd" -eq 1 ]; then
    detected_gpu_mode="amd-nvidia-hybrid"
  elif [ "$has_nvidia" -eq 1 ] && [ "$has_intel" -eq 1 ]; then
    detected_gpu_mode="nvidia-prime"
  elif [ "$has_nvidia" -eq 1 ]; then
    detected_gpu_mode="nvidia"
  elif [ "$has_amd" -eq 1 ]; then
    detected_gpu_mode="amd"
  elif [ "$has_intel" -eq 1 ]; then
    detected_gpu_mode="modesetting"
  fi
}

set_nix_string_or_null() {
  local file="$1"
  local key="$2"
  local value="$3"
  local value_expr="null"

  if [ -n "$value" ]; then
    value_expr="\"$value\""
  fi

  if grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
    sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|  ${key} = ${value_expr};|" "$file"
  fi
}

set_nix_string_field() {
  local file="$1"
  local key="$2"
  local value="$3"

  if [ -z "$value" ]; then
    return 0
  fi

  if grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
    sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|  ${key} = \"${value}\";|" "$file"
  fi
}

if ! is_valid_host_name "$host_name"; then
  echo "error: invalid host name '$host_name' (allowed: [A-Za-z0-9][A-Za-z0-9_-]*)" >&2
  exit 2
fi

repo="$(resolve_repo_path "$repo")"

case "$platform" in
  nixos)
    source_host="${source_host:-zly}"
    root_dir="$repo/nix/hosts/nixos"
    required_files=(hardware.nix disko.nix vars.nix)
    optional_files=(host.nix home.nix checks.nix)
    optional_dirs=(modules home-modules)
    ;;
  darwin)
    source_host="${source_host:-zly-mac}"
    root_dir="$repo/nix/hosts/darwin"
    required_files=(default.nix vars.nix)
    optional_files=(home.nix checks.nix)
    optional_dirs=(modules home-modules)
    ;;
  *)
    echo "error: platform must be 'nixos' or 'darwin', got '$platform'" >&2
    exit 2
    ;;
esac

if [ -n "$gpu_mode" ] && [ "$platform" != "nixos" ]; then
  echo "error: --gpu-mode only supports nixos hosts" >&2
  exit 2
fi

if [ -n "$gpu_mode" ] && ! is_valid_gpu_mode "$gpu_mode"; then
  echo "error: invalid gpu mode '$gpu_mode'" >&2
  echo "allowed: auto, none, amd, amdgpu, nvidia, nvidia-prime, modesetting, amd-nvidia-hybrid" >&2
  exit 2
fi

if ! is_valid_host_name "$source_host"; then
  echo "error: invalid source host name '$source_host' (allowed: [A-Za-z0-9][A-Za-z0-9_-]*)" >&2
  exit 2
fi

source_dir="$root_dir/$source_host"
target_dir="$root_dir/$host_name"

if [ ! -d "$source_dir" ]; then
  echo "error: source host directory not found: $source_dir" >&2
  exit 1
fi

for file in "${required_files[@]}"; do
  if [ ! -f "$source_dir/$file" ]; then
    echo "error: missing required source file: $source_dir/$file" >&2
    exit 1
  fi
done

if [ -e "$target_dir" ] && [ "$force" -ne 1 ]; then
  echo "error: target host already exists: $target_dir" >&2
  echo "hint: use --force to overwrite" >&2
  exit 1
fi

echo ">>> platform: $platform"
echo ">>> source:   $source_dir"
echo ">>> target:   $target_dir"

if [ "$dry_run" -eq 1 ]; then
  echo "dry-run: no files changed"
  exit 0
fi

if [ -d "$target_dir" ]; then
  rm -rf "$target_dir"
  mkdir -p "$target_dir"
else
  mkdir -p "$target_dir"
fi

for file in "${required_files[@]}"; do
  cp "$source_dir/$file" "$target_dir/$file"
done

for file in "${optional_files[@]}"; do
  if [ -f "$source_dir/$file" ]; then
    cp "$source_dir/$file" "$target_dir/$file"
  fi
done

for dir in "${optional_dirs[@]}"; do
  if [ -d "$source_dir/$dir" ]; then
    cp -a "$source_dir/$dir" "$target_dir/$dir"
  fi
done

if [ "$source_host" != "$host_name" ]; then
  source_pat="$(escape_sed_pattern "$source_host")"
  target_pat="$(escape_sed_pattern "$host_name")"

  while IFS= read -r -d '' nix_file; do
    sed -i.bak \
      -e "s/\"${source_pat}\"/\"${target_pat}\"/g" \
      -e "s#/\\.ssh/${source_pat}#/\\.ssh/${target_pat}#g" \
      "$nix_file"
  done < <(find "$target_dir" -type f -name '*.nix' -print0)

  find "$target_dir" -type f -name '*.bak' -delete
fi

if [ "$platform" = "nixos" ] && [ -f "$target_dir/vars.nix" ]; then
  detect_gpu_settings

  effective_gpu_mode="$gpu_mode"
  if [ -z "$effective_gpu_mode" ]; then
    effective_gpu_mode="$detected_gpu_mode"
  fi

  if [ -n "$effective_gpu_mode" ]; then
    set_nix_string_field "$target_dir/vars.nix" "gpuMode" "$effective_gpu_mode"
    echo ">>> gpuMode set to: $effective_gpu_mode"
  else
    echo "warning: unable to auto-detect gpu mode; keeping template gpuMode" >&2
  fi

  set_nix_string_or_null "$target_dir/vars.nix" "intelBusId" "$detected_intel_bus_id"
  set_nix_string_or_null "$target_dir/vars.nix" "amdgpuBusId" "$detected_amdgpu_bus_id"
  set_nix_string_or_null "$target_dir/vars.nix" "nvidiaBusId" "$detected_nvidia_bus_id"
  echo ">>> bus IDs: intel=${detected_intel_bus_id:-null} amdgpu=${detected_amdgpu_bus_id:-null} nvidia=${detected_nvidia_bus_id:-null}"
fi

echo "created host: $platform/$host_name"
echo "next:"
echo "  just hosts"
echo "  just eval-tests"
echo "  # then edit: $target_dir/vars.nix (and hardware/disko if needed)"
