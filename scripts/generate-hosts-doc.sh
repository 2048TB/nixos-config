#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/generate-hosts-doc.sh
  ./scripts/generate-hosts-doc.sh --check
EOF
}

check_only=false
if [[ $# -gt 1 ]]; then
  usage >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  case "$1" in
    --check)
      check_only=true
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
fi

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output_file="$repo_root/docs/hosts.md"
tmp_file=$(mktemp)

cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT

nix eval --impure --raw --expr "
  let
    renderer = import \"$repo_root/nix/shared/render-hosts-doc.nix\";
  in
  renderer { repoRoot = \"$repo_root\"; }
" >"$tmp_file"

if [[ "$check_only" == true ]]; then
  if cmp -s "$tmp_file" "$output_file"; then
    printf 'Verified %s is up to date\n' "$output_file"
    exit 0
  fi

  echo "docs/hosts.md is out of date. Re-run ./scripts/generate-hosts-doc.sh" >&2
  diff -u "$output_file" "$tmp_file" || true
  exit 1
fi

mv "$tmp_file" "$output_file"
trap - EXIT

printf 'Generated %s\n' "$output_file"
