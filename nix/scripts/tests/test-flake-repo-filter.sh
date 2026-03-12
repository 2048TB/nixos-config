#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'chmod -R u+rwX "$tmpdir" 2>/dev/null || true; rm -rf "$tmpdir"' EXIT

tmprepo="$tmpdir/repo"
mkdir -p "$tmprepo/.keys"
cat >"$tmprepo/flake.nix" <<'EOF'
{
  description = "test flake";
  outputs = _: { };
}
EOF

printf 'AGE-SECRET-KEY-TEST\n' >"$tmprepo/.keys/main.agekey"
chmod 000 "$tmprepo/.keys/main.agekey"

filtered_repo="$(bash "$repo_root/nix/scripts/admin/print-flake-repo.sh" "$tmprepo")"

if [ "$filtered_repo" = "$tmprepo" ]; then
  echo "expected filtered repo path when .keys/main.agekey is unreadable" >&2
  exit 1
fi

if [ ! -f "$filtered_repo/flake.nix" ]; then
  echo "expected filtered repo to contain flake.nix" >&2
  exit 1
fi

if [ -e "$filtered_repo/.keys/main.agekey" ]; then
  echo "expected filtered repo to exclude .keys/main.agekey" >&2
  exit 1
fi

chmod 0600 "$tmprepo/.keys/main.agekey"
same_repo="$(bash "$repo_root/nix/scripts/admin/print-flake-repo.sh" "$tmprepo")"

if [ "$same_repo" != "$tmprepo" ]; then
  echo "expected original repo path when .keys/main.agekey is readable" >&2
  exit 1
fi
