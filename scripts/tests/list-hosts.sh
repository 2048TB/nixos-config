#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
bash_bin=$(command -v bash)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts" "$tmpdir/nix/registry"

cat >"$tmpdir/nix/registry/systems.toml" <<'EOF'
[nixos.gamma]
platform = "nixos"

[nixos.alpha]
platform = "nixos"

[darwin.mbp]
platform = "darwin"
EOF

actual=$("$bash_bin" "$repo_root/scripts/list-hosts.sh" nixos "$tmpdir")
expected=$'alpha\ngamma'

if [[ "$actual" != "$expected" ]]; then
  echo "unexpected nixos host list" >&2
  echo "expected:" >&2
  printf '%s\n' "$expected" >&2
  echo "actual:" >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi

actual=$("$bash_bin" "$repo_root/scripts/list-hosts.sh" darwin "$tmpdir")
expected=$'mbp'

if [[ "$actual" != "$expected" ]]; then
  echo "unexpected darwin host list" >&2
  echo "expected:" >&2
  printf '%s\n' "$expected" >&2
  echo "actual:" >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi
