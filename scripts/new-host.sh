#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage:
  new-host.sh <nixos|darwin> <host-name> [--from <source-host>] [--repo <repo>] [--dry-run] [--force]

examples:
  new-host.sh nixos zbook --from zly
  new-host.sh darwin mbp14 --from zly-mac
  new-host.sh nixos devbox --dry-run
EOF
}

is_valid_host_name() {
  local name="${1:-}"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

escape_sed_pattern() {
  # shellcheck disable=SC2016
  printf '%s' "$1" | sed -e 's/[\/&.[\*^$()+?{}|]/\\&/g'
}

platform="${1:-}"
host_name="${2:-}"
shift "$(( $# >= 2 ? 2 : $# ))"

source_host=""
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

if ! is_valid_host_name "$host_name"; then
  echo "error: invalid host name '$host_name' (allowed: [A-Za-z0-9][A-Za-z0-9._-]*)" >&2
  exit 2
fi

if [ ! -f "$repo/flake.nix" ] && [ -f "/persistent/nixos-config/flake.nix" ]; then
  repo="/persistent/nixos-config"
fi

case "$platform" in
  nixos)
    source_host="${source_host:-zly}"
    root_dir="$repo/hosts/nixos"
    required_files=(hardware.nix disko.nix vars.nix)
    optional_files=(host.nix home.nix checks.nix)
    optional_dirs=(modules home-modules)
    ;;
  darwin)
    source_host="${source_host:-zly-mac}"
    root_dir="$repo/hosts/darwin"
    required_files=(default.nix vars.nix)
    optional_files=(home.nix checks.nix)
    optional_dirs=(modules home-modules)
    ;;
  *)
    echo "error: platform must be 'nixos' or 'darwin', got '$platform'" >&2
    exit 2
    ;;
esac

if ! is_valid_host_name "$source_host"; then
  echo "error: invalid source host name '$source_host' (allowed: [A-Za-z0-9][A-Za-z0-9._-]*)" >&2
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
  find "$target_dir" -type f -name '*.nix' -exec sed -i.bak "s/${source_pat}/${target_pat}/g" {} +
  find "$target_dir" -type f -name '*.bak' -delete
fi

echo "created host: $platform/$host_name"
echo "next:"
echo "  just hosts"
echo "  just eval-tests"
echo "  # then edit: $target_dir/vars.nix (and hardware/disko if needed)"
