#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  repo-check.sh
  repo-check.sh --full
EOF
}

full_check=0

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  case "$1" in
    --full)
      full_check=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

repo_root="$(resolve_repo_path "${NIXOS_CONFIG_REPO:-$PWD}")"
cd "$repo_root"

echo "==> shell syntax"
bash -n nix/scripts/admin/*.sh

echo "==> shell regression tests"
for test_script in nix/scripts/tests/*.sh; do
  bash "$test_script"
done

echo "==> nix formatting check"
nix shell "path:$repo_root#formatter.x86_64-linux" -c \
  nixpkgs-fmt --check flake.nix $(find nix -type f -name '*.nix' | sort)

echo "==> eval tests"
just eval-tests

echo "==> flake check"
nix --extra-experimental-features 'nix-command flakes' flake check --all-systems "path:$repo_root"

if [[ "$full_check" -eq 1 ]]; then
  echo "==> dry-build nixos hosts"
  while IFS= read -r host; do
    [[ -n "$host" ]] || continue
    nix build --no-link "path:$repo_root#nixosConfigurations.$host.config.system.build.toplevel"
  done < <(
    nix eval --raw "path:$repo_root#nixosConfigurations" \
      --apply 'hosts: builtins.concatStringsSep "\n" (builtins.attrNames hosts)'
  )

  echo "==> dry-build darwin hosts"
  while IFS= read -r host; do
    [[ -n "$host" ]] || continue
    nix build --no-link "path:$repo_root#darwinConfigurations.$host.system"
  done < <(
    nix eval --raw "path:$repo_root#darwinConfigurations" \
      --apply 'hosts: builtins.concatStringsSep "\n" (builtins.attrNames hosts)'
  )
fi
