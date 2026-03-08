#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

platform="${1:-}"
repo="${2:-${NIXOS_CONFIG_REPO:-$PWD}}"
fallback="${3:-}"
strict_mode=0
strict_flag="${4:-}"

usage() {
  echo "usage: resolve-host.sh <nixos|darwin> <repo> <fallback-host> [--strict]"
}

if [ "$platform" = "-h" ] || [ "$platform" = "--help" ]; then
  usage
  exit 0
fi

if [ -z "$platform" ] || [ -z "$fallback" ]; then
  usage >&2
  exit 2
fi

if [ -n "$strict_flag" ]; then
  if [ "$strict_flag" != "--strict" ]; then
    echo "error: unknown argument '$strict_flag' (only --strict is supported)" >&2
    exit 2
  fi
  strict_mode=1
fi

repo="$(resolve_repo_path "$repo")"

detect_nixos_host() {
  if [ "$(uname -s)" != "Linux" ]; then
    return
  fi
  if command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl --static 2>/dev/null || true
    return
  fi
  hostname -s 2>/dev/null || hostname 2>/dev/null || true
}

detect_darwin_host() {
  if [ "$(uname -s)" != "Darwin" ]; then
    return
  fi
  if command -v scutil >/dev/null 2>&1; then
    scutil --get LocalHostName 2>/dev/null || true
    return
  fi
  hostname -s 2>/dev/null || hostname 2>/dev/null || true
}

normalize_host() {
  local raw="${1:-}"
  printf '%s' "${raw%%.*}"
}

case "$platform" in
  nixos)
    env_candidate="${NIXOS_HOST:-}"
    detected_candidate="$(detect_nixos_host)"
    hosts_root="$repo/nix/hosts/nixos"
    required_files=(hardware.nix disko.nix vars.nix)
    ;;
  darwin)
    env_candidate="${DARWIN_HOST:-}"
    detected_candidate="$(detect_darwin_host)"
    hosts_root="$repo/nix/hosts/darwin"
    required_files=(default.nix vars.nix)
    ;;
  *)
    echo "error: platform must be 'nixos' or 'darwin', got '$platform'" >&2
    exit 2
    ;;
esac

host_exists() {
  local host="${1:-}"
  local file
  if [ -z "$host" ] || ! is_valid_host_name "$host" || [ ! -d "$hosts_root/$host" ]; then
    return 1
  fi
  for file in "${required_files[@]}"; do
    if [ ! -f "$hosts_root/$host/$file" ]; then
      return 1
    fi
  done
}

first_available_host() {
  local path host
  for path in "$hosts_root"/*; do
    [ -d "$path" ] || continue
    host="$(basename "$path")"
    if host_exists "$host"; then
      echo "$host"
      return 0
    fi
  done
  return 1
}

if [ -n "$env_candidate" ]; then
  resolved_env="$env_candidate"
  if ! is_valid_host_name "$resolved_env"; then
    echo "warning: ${platform} host from env is invalid: '$resolved_env'" >&2
    resolved_env=""
  fi
fi

if [ -n "${resolved_env:-}" ]; then
  if host_exists "$resolved_env"; then
    echo "$resolved_env"
    exit 0
  fi
  echo "warning: ${platform} host from env not found in repo: '$resolved_env'" >&2
  if [ "$strict_mode" -eq 1 ]; then
    echo "error: strict mode requires a valid host from environment or current hostname" >&2
    exit 1
  fi
fi

if [ -n "$detected_candidate" ]; then
  resolved_detected="$(normalize_host "$detected_candidate")"
  if ! is_valid_host_name "$resolved_detected"; then
    echo "warning: ${platform} host from hostname is invalid: '$resolved_detected'" >&2
    resolved_detected=""
  fi
fi

if [ -n "${resolved_detected:-}" ]; then
  if host_exists "$resolved_detected"; then
    echo "$resolved_detected"
    exit 0
  fi
  echo "warning: ${platform} host from hostname not found in repo: '$resolved_detected'" >&2
  if [ "$strict_mode" -eq 1 ]; then
    echo "error: strict mode requires a valid host from environment or current hostname" >&2
    exit 1
  fi
fi

if [ "$strict_mode" -eq 1 ]; then
  echo "error: strict mode requires a valid host from environment or current hostname" >&2
  exit 1
fi

if ! is_valid_host_name "$fallback"; then
  echo "error: invalid fallback host name '$fallback'" >&2
  exit 2
fi

if host_exists "$fallback"; then
  echo "$fallback"
  exit 0
fi

auto_fallback="$(first_available_host || true)"
if [ -n "$auto_fallback" ]; then
  echo "warning: fallback host '$fallback' is unavailable, use '$auto_fallback' instead" >&2
  echo "$auto_fallback"
  exit 0
fi

echo "error: no valid ${platform} hosts found under $hosts_root" >&2
exit 1
