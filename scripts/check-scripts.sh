#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

shopt -s nullglob
files=(scripts/*.sh .githooks/pre-*)
shopt -u nullglob

if [ "${#files[@]}" -eq 0 ]; then
  echo "warning: no shell scripts found"
  exit 0
fi

echo "checking ${#files[@]} files..."
bash -n "${files[@]}"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${files[@]}"
else
  echo "warning: shellcheck not found, skipped"
fi
