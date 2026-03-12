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

mkdir -p "$tmpdir/rootfs/etc"
cat >"$tmpdir/rootfs/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/run/current-system/sw/bin/bash
z:x:1200:1300::/home/z:/run/current-system/sw/bin/zsh
EOF

actual="$(resolve_target_owner_from_rootfs "$tmpdir/rootfs" "z")"
expected="1200:1300"

if [[ "$actual" != "$expected" ]]; then
  echo "expected owner $expected, got $actual" >&2
  exit 1
fi

required_tracked_paths=(
  "nix/modules/core/_mixins/default.nix"
  "nix/modules/core/_mixins/README.md"
  "nix/home/linux/_mixins/default.nix"
  "nix/home/linux/_mixins/README.md"
  "nix/lib/display-topology.nix"
  "nix/hosts/nixos/_shared/generated-desktop-checks.nix"
)

if ! git -C "$repo_root" ls-files --error-unmatch "${required_tracked_paths[@]}" >/dev/null 2>&1; then
  echo "expected critical flake source files to be tracked in git" >&2
  exit 1
fi

fake_repo="$tmpdir/fake-repo"
mkdir -p "$fake_repo"
git -C "$fake_repo" init -q

cat >"$fake_repo/flake.nix" <<'EOF'
{
  description = "fake";
  outputs = _: { };
}
EOF

mkdir -p "$fake_repo/nix/modules"
cat >"$fake_repo/nix/modules/tracked.nix" <<'EOF'
{ }
EOF

mkdir -p "$fake_repo/.keys"
cat >"$fake_repo/.keys/main.agekey" <<'EOF'
AGE-SECRET-KEY-TEST
EOF
chmod 000 "$fake_repo/.keys/main.agekey"

git -C "$fake_repo" add flake.nix nix/modules/tracked.nix

mkdir -p "$fake_repo/nix/untracked"
cat >"$fake_repo/nix/untracked/local-only.nix" <<'EOF'
{ }
EOF

prepare_flake_repo_path "$fake_repo"
prepared_repo="$PREPARED_FLAKE_REPO"

if [[ ! -f "$prepared_repo/flake.nix" ]]; then
  echo "expected prepared flake repo to keep tracked flake.nix" >&2
  exit 1
fi

if [[ ! -f "$prepared_repo/nix/modules/tracked.nix" ]]; then
  echo "expected prepared flake repo to keep tracked source files" >&2
  exit 1
fi

if [[ -e "$prepared_repo/.keys/main.agekey" ]]; then
  echo "expected prepared flake repo to exclude unreadable .keys/main.agekey" >&2
  exit 1
fi

if [[ -e "$prepared_repo/nix/untracked/local-only.nix" ]]; then
  echo "expected prepared flake repo to exclude untracked source files" >&2
  exit 1
fi
