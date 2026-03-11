#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/../admin/common.sh"

repo_root="$(resolve_repo_path "${NIXOS_CONFIG_REPO:-$PWD}")"
cd "$repo_root"

mapfile -t inputs < <(
  awk '
    /inputs = \{/ { in_inputs=1; next }
    in_inputs && /^  \};/ { exit }
    in_inputs && /^    [A-Za-z0-9_.-]+[[:space:]]*=/ {
      line=$0
      sub(/^    /, "", line)
      sub(/[[:space:]]*=.*/, "", line)
      sub(/\..*/, "", line)
      print line
    }
  ' flake.nix
)

printf '| input | category | used by | keep | note |\n'
printf '|------|----------|---------|------|------|\n'

for input in "${inputs[@]}"; do
  case "$input" in
    nixpkgs* | home-manager | nix-darwin) category="core" ;;
    homebrew-* | nix-homebrew) category="darwin" ;;
    rust-overlay | noctalia | nix-gaming) category="packages" ;;
    nixos-hardware | lanzaboote | preservation | disko | sops-nix) category="modules" ;;
    pre-commit-hooks) category="ci" ;;
    *) category="unknown" ;;
  esac

  mapfile -t refs < <(
    rg -l --fixed-strings "$input" nix .github flake.nix \
      | grep -v '^flake.lock$' \
      | sed -n '1,3p'
  )

  if [ "${#refs[@]}" -eq 0 ]; then
    used_by="none found"
    keep="review"
    note="No static reference outside lockfile; verify dynamic usage before deletion."
  else
    used_by="$(IFS='<br>'; printf '%s' "${refs[*]}")"
    keep="yes"
    note="Static references found."
  fi

  printf '| %s | %s | %s | %s | %s |\n' "$input" "$category" "$used_by" "$keep" "$note"
done
