#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"
justfile="$repo_root/justfile"

# shellcheck disable=SC1091
source "$repo_root/nix/scripts/admin/common.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

if rg -n '^[[:space:]]*git add \.$' "$justfile" >/dev/null; then
  echo "expected justfile to avoid 'git add .'" >&2
  exit 1
fi

if ! sed -n '/^clean-all:/,/^[^[:space:]]/p' "$justfile" | rg -n 'confirm_destructive_action' >/dev/null; then
  echo "expected clean-all recipe to require destructive-action confirmation" >&2
  exit 1
fi

confirm_stderr="$tmpdir/confirm.stderr"
if confirm_destructive_action "ERASE /dev/nvme0n1" "test message" 0 </dev/null 2>"$confirm_stderr"; then
  echo "expected non-interactive confirmation to fail without --yes" >&2
  exit 1
fi

if ! rg -n --fixed-strings "rerun with --yes" "$confirm_stderr" >/dev/null; then
  echo "expected confirmation failure to mention --yes override" >&2
  exit 1
fi

if validate_block_device_path "/tmp/not-a-device" >"$tmpdir/disk.stdout" 2>"$tmpdir/disk.stderr"; then
  echo "expected non-/dev path validation to fail" >&2
  exit 1
fi

if ! rg -n --fixed-strings "must start with /dev/" "$tmpdir/disk.stderr" >/dev/null; then
  echo "expected path validation failure message for non-/dev path" >&2
  exit 1
fi

mkdir -p "$tmpdir/bin"

cat >"$tmpdir/bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "nix should not be called for invalid disk input" >&2
exit 99
EOF
chmod +x "$tmpdir/bin/nix"

cat >"$tmpdir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "sudo should not be called for invalid disk input" >&2
exit 98
EOF
chmod +x "$tmpdir/bin/sudo"

stderr_file="$tmpdir/install.stderr"
if PATH="$tmpdir/bin:$PATH" bash "$repo_root/nix/scripts/admin/install-live.sh" \
  --host zly \
  --disk /tmp/not-a-device \
  --repo "$repo_root" \
  --yes \
  >"$tmpdir/install.stdout" 2>"$stderr_file"; then
  echo "expected install-live.sh to reject invalid disk path" >&2
  exit 1
fi

if ! rg -n --fixed-strings "must start with /dev/" "$stderr_file" >/dev/null; then
  echo "expected invalid disk failure to explain the /dev/ requirement" >&2
  exit 1
fi

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

actual="$(PATH="$tmpdir/bin:$PATH" resolve_target_owner_from_config "$repo_root" "zly" "z")"
expected="1200:1300"

if [[ "$actual" != "$expected" ]]; then
  echo "expected owner $expected, got $actual" >&2
  exit 1
fi
