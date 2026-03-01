#!/usr/bin/env bash

# Shared helper functions for repository scripts.
# Intentionally does not set shell options; caller scripts are responsible.

is_valid_host_name() {
  local name="${1:-}"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

resolve_repo_path() {
  local candidate="${1:-$PWD}"
  if [ ! -f "$candidate/flake.nix" ] && [ -f "/persistent/nixos-config/flake.nix" ]; then
    candidate="/persistent/nixos-config"
  fi
  if [ ! -f "$candidate/flake.nix" ]; then
    echo "error: flake.nix not found in repo: $candidate" >&2
    return 1
  fi
  printf '%s\n' "$candidate"
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
