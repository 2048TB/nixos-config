#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/repo-check.sh
  ./scripts/repo-check.sh --full
EOF
}

full_check=false
if [[ $# -gt 1 ]]; then
  usage >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  case "$1" in
    --full)
      full_check=true
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
fi

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

echo "==> shell syntax"
bash -n scripts/*.sh

echo "==> shell regression tests"
for test_script in scripts/tests/*.sh; do
  bash "$test_script"
done

echo "==> nix formatting check"
mapfile -t nix_files < <(./scripts/list-nix-files.sh)
if [[ ${#nix_files[@]} -eq 0 ]]; then
  echo "no .nix files found for formatting check" >&2
  exit 1
fi
nix shell .#formatter.x86_64-linux -c nixfmt --check "${nix_files[@]}"

echo "==> hosts doc drift check"
./scripts/generate-hosts-doc.sh --check

echo "==> flake check"
nix flake check

if [[ "$full_check" == true ]]; then
  while IFS= read -r host; do
    echo "==> dry-run nixosConfigurations.${host}"
    nix build --dry-run ".#nixosConfigurations.${host}.config.system.build.toplevel"
  done < <(bash ./scripts/list-hosts.sh nixos "$repo_root")

  while IFS= read -r host; do
    echo "==> dry-run darwinConfigurations.${host}"
    nix build --dry-run ".#darwinConfigurations.${host}.system"
  done < <(bash ./scripts/list-hosts.sh darwin "$repo_root")

  echo "==> dry-run homeConfigurations.z@template-linux"
  nix build --dry-run '.#homeConfigurations."z@template-linux".activationPackage'

  echo "==> dry-run homeConfigurations.z@mbp-work"
  nix build --dry-run '.#homeConfigurations."z@mbp-work".activationPackage'
fi
