#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"

# shellcheck disable=SC1091
source "$repo_root/nix/scripts/admin/common.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin"

cat >"$tmpdir/bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *'users.users."z".uid'* ]]; then
  printf '1200\n'
elif [[ "$*" == *'users.groups."z".gid'* ]]; then
  printf '1300\n'
else
  echo "unexpected nix eval query: $*" >&2
  exit 1
fi
EOF
chmod +x "$tmpdir/bin/nix"

PATH="$tmpdir/bin:$PATH"

actual="$(resolve_target_owner_from_config "$repo_root" "zly" "z")"
expected="1200:1300"

if [[ "$actual" != "$expected" ]]; then
  echo "expected owner $expected, got $actual" >&2
  exit 1
fi
