#!/usr/bin/env bash
set -euo pipefail

repo_root=${1:-.}

cd "$repo_root"

if command -v rg >/dev/null 2>&1; then
  rg --files -g '*.nix'
  exit 0
fi

while IFS= read -r path; do
  printf '%s\n' "${path#./}"
done < <(find . -type f -name '*.nix')
