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
