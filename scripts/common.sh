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

  script_repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
  if [ -f "$script_repo/flake.nix" ]; then
    printf '%s\n' "$script_repo"
    return 0
  fi

  echo "error: flake.nix not found in repo: $candidate" >&2
  return 1
}

enter_repo_root() {
  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  cd "$repo_root" || return 1
  printf '%s\n' "$repo_root"
}

run_agenix() {
  if command -v agenix >/dev/null 2>&1; then
    agenix "$@"
  else
    nix run github:ryantm/agenix -- "$@"
  fi
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

# Non-interactive agenix encryption: write content from a source file to an .age secret.
# Usage: run_agenix_encrypt <content-file> <secret-rel-path> <identity-file>
run_agenix_encrypt() {
  local content_file="$1"
  local secret_rel="$2"
  local identity="$3"
  # agenix 在非交互 stdin 下会忽略外部 EDITOR 并强制走 "cp /dev/stdin"。
  # 直接通过 stdin 注入内容，避免写入空 secret。
  cat "$content_file" | run_agenix -e "$secret_rel" -i "$identity"
}
