#!/usr/bin/env bash

# Shared helper functions for repository scripts.
# Intentionally does not set shell options; caller scripts are responsible.

is_valid_host_name() {
  local name="${1:-}"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]
}

resolve_repo_path() {
  local candidate="${1:-${NIXOS_CONFIG_REPO:-$PWD}}"
  local repo_root=""
  local script_repo=""

  if [ -f "$candidate/flake.nix" ]; then
    (cd "$candidate" && pwd -P)
    return 0
  fi

  if repo_root="$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null)"; then
    if [ -f "$repo_root/flake.nix" ]; then
      printf '%s\n' "$repo_root"
      return 0
    fi
  fi

  script_repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
  if [ -f "$script_repo/flake.nix" ]; then
    printf '%s\n' "$script_repo"
    return 0
  fi

  echo "error: flake.nix not found in repo: $candidate" >&2
  return 1
}

needs_filtered_flake_repo() {
  local repo_root="${1:?repo root required}"
  local key_path="$repo_root/.keys/main.agekey"
  [ -e "$key_path" ] && [ ! -r "$key_path" ]
}

prepare_flake_repo_path() {
  local repo_root="${1:?repo root required}"
  local cache_key=""
  local cache_root=""

  PREPARED_FLAKE_REPO="$repo_root"

  if ! needs_filtered_flake_repo "$repo_root"; then
    return 0
  fi

  cache_key="$(printf '%s' "$repo_root" | cksum | awk '{print $1}')"
  cache_root="${TMPDIR:-/tmp}/nixos-config-flake-$(id -u)-${cache_key}"

  mkdir -p "$cache_root/repo"
  rsync -a --delete \
    --exclude '.git/' \
    --exclude '.keys/' \
    --exclude '.serena/' \
    --exclude 'result' \
    --exclude 'result-*' \
    "$repo_root/" "$cache_root/repo/"

  PREPARED_FLAKE_REPO="$cache_root/repo"
}

enter_repo_root() {
  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  cd "$repo_root" || return 1
  printf '%s\n' "$repo_root"
}

run_age_keygen() {
  if command -v age-keygen >/dev/null 2>&1; then
    age-keygen "$@"
  else
    nix shell nixpkgs#age -c age-keygen "$@"
  fi
}

run_ssh_keygen() {
  if command -v ssh-keygen >/dev/null 2>&1; then
    ssh-keygen "$@"
  else
    nix shell nixpkgs#openssh -c ssh-keygen "$@"
  fi
}

run_ssh_to_age() {
  if command -v ssh-to-age >/dev/null 2>&1; then
    ssh-to-age "$@"
  else
    nix shell nixpkgs#age -c ssh-to-age "$@"
  fi
}

run_sops() {
  if command -v sops >/dev/null 2>&1; then
    sops "$@"
  else
    nix shell nixpkgs#sops -c sops "$@"
  fi
}

# Encrypt YAML from stdin to target path with selected age recipients.
# Usage: run_sops_encrypt_yaml <recipient-csv> <target-file>
run_sops_encrypt_yaml() {
  local recipients="$1"
  local target_file="$2"

  if [ -z "$recipients" ]; then
    echo "error: empty sops recipient list" >&2
    return 1
  fi

  run_sops --encrypt --age "$recipients" --input-type yaml --output-type yaml /dev/stdin >"$target_file"
}

confirm_destructive_action() {
  local token="${1:?confirmation token required}"
  local message="${2:-}"
  local assume_yes="${3:-0}"
  local answer=""

  if [ "$assume_yes" = "1" ]; then
    return 0
  fi

  if [ -n "$message" ]; then
    printf '%s\n' "$message" >&2
  fi

  if [ ! -t 0 ]; then
    echo "error: destructive action requires confirmation; rerun with --yes if intended" >&2
    return 1
  fi

  printf 'Type "%s" to continue: ' "$token" >&2
  IFS= read -r answer
  if [ "$answer" != "$token" ]; then
    echo "error: confirmation token mismatch" >&2
    return 1
  fi
}

validate_block_device_path() {
  local disk="${1:-}"

  if [[ "$disk" != /dev/* ]]; then
    echo "error: disk path must start with /dev/: $disk" >&2
    return 1
  fi

  if [ ! -b "$disk" ]; then
    echo "error: disk path is not a block device: $disk" >&2
    return 1
  fi
}

resolve_target_owner_from_config() {
  local repo_root="${1:?repo root required}"
  local host="${2:?host required}"
  local username="${3:?username required}"
  local uid=""
  local gid=""

  uid="$(
    nix eval --raw "path:${repo_root}#nixosConfigurations.${host}.config.users.users.\"${username}\".uid"
  )"
  gid="$(
    nix eval --raw "path:${repo_root}#nixosConfigurations.${host}.config.users.groups.\"${username}\".gid"
  )"
  printf '%s:%s\n' "$uid" "$gid"
}
