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
prepare_flake_repo_path "$repo_root"
flake_repo="$PREPARED_FLAKE_REPO"

echo "==> shell syntax"
bash -n nix/scripts/admin/*.sh nix/scripts/checks/*.sh nix/scripts/tests/*.sh

echo "==> shell regression tests"
for test_script in nix/scripts/tests/*.sh; do
  bash "$test_script"
done

echo "==> registry check"
bash nix/scripts/checks/registry-check.sh

echo "==> nix formatting check"
nix shell "path:$flake_repo#formatter.x86_64-linux" -c \
  nixpkgs-fmt --check flake.nix $(find nix -type f -name '*.nix' | sort)

echo "==> eval tests"
bash nix/scripts/admin/eval-tests.sh "$repo_root"

echo "==> flake check"
run_nix_flake_check_clean "path:$flake_repo"

if [[ "$full_check" -eq 1 ]]; then
  echo "==> dry-build nixos hosts"
  while IFS= read -r host; do
    [[ -n "$host" ]] || continue
    nix build --no-link "path:$flake_repo#nixosConfigurations.$host.config.system.build.toplevel"
  done < <(
    nix eval --raw "path:$flake_repo#nixosConfigurations" \
      --apply 'hosts: builtins.concatStringsSep "\n" (builtins.attrNames hosts)'
  )

  echo "==> dry-build darwin hosts"
  while IFS= read -r host; do
    [[ -n "$host" ]] || continue
    nix build --no-link "path:$flake_repo#darwinConfigurations.$host.system"
  done < <(
    nix eval --raw "path:$flake_repo#darwinConfigurations" \
      --apply 'hosts: builtins.concatStringsSep "\n" (builtins.attrNames hosts)'
  )
fi
