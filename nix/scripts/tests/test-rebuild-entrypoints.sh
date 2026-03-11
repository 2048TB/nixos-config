#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"
justfile="$repo_root/justfile"
real_bash="$(command -v bash)"
original_path="$PATH"

extract_recipe() {
  local name="$1"
  awk -v recipe="$name" '
    $0 ~ ("^" recipe ":") { in_recipe=1; next }
    in_recipe && $0 ~ /^[^[:space:]]/ { exit }
    in_recipe { print }
  ' "$justfile"
}

output="$(bash "$repo_root/nix/scripts/admin/preflight-switch.sh" 2>&1 || true)"
if [[ "$output" != *"Usage:"* ]]; then
  echo "expected usage output, got: $output" >&2
  exit 1
fi

if [ -e "$repo_root/nix/scripts/admin/rebuild-auto.sh" ]; then
  echo "expected unused rebuild-auto.sh entrypoint to be removed" >&2
  exit 1
fi

switch_recipe="$(extract_recipe switch)"
switch_safe_recipe="$(extract_recipe switch-safe)"
boot_recipe="$(extract_recipe boot)"
boot_safe_recipe="$(extract_recipe boot-safe)"
test_recipe="$(extract_recipe test)"
test_safe_recipe="$(extract_recipe test-safe)"
check_recipe="$(extract_recipe check)"
darwin_switch_recipe="$(extract_recipe darwin-switch)"
darwin_switch_safe_recipe="$(extract_recipe darwin-switch-safe)"
darwin_check_recipe="$(extract_recipe darwin-check)"

for recipe_body in \
  "$switch_recipe" \
  "$switch_safe_recipe" \
  "$boot_recipe" \
  "$boot_safe_recipe" \
  "$test_recipe" \
  "$test_safe_recipe" \
  "$check_recipe"; do
  if [[ "$recipe_body" != *"rebuild-nixos.sh"* ]]; then
    echo "expected nixos recipes to delegate to rebuild-nixos.sh" >&2
    exit 1
  fi
done

for recipe_body in "$darwin_switch_recipe" "$darwin_switch_safe_recipe" "$darwin_check_recipe"; do
  if [[ "$recipe_body" != *"rebuild-darwin.sh"* ]]; then
    echo "expected darwin recipes to delegate to rebuild-darwin.sh" >&2
    exit 1
  fi
done

if printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
  "$switch_recipe" \
  "$switch_safe_recipe" \
  "$boot_recipe" \
  "$boot_safe_recipe" \
  "$test_recipe" \
  "$test_safe_recipe" \
  "$check_recipe" \
  "$darwin_switch_recipe" \
  "$darwin_switch_safe_recipe" \
  "$darwin_check_recipe" | rg -n 'resolve-host\.sh|preflight-switch\.sh|nixos-rebuild|darwin-rebuild' >/dev/null; then
  echo "expected rebuild logic to move out of justfile recipes" >&2
  exit 1
fi

if [[ "$switch_safe_recipe" != *"REBUILD_PREFLIGHT=1"* ]] || \
  [[ "$boot_safe_recipe" != *"REBUILD_PREFLIGHT=1"* ]] || \
  [[ "$test_safe_recipe" != *"REBUILD_PREFLIGHT=1"* ]] || \
  [[ "$darwin_switch_safe_recipe" != *"REBUILD_PREFLIGHT=1"* ]]; then
  echo "expected safe recipes to enable REBUILD_PREFLIGHT" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/bin" "$tmpdir/logs"

printf '#!%s\n' "$real_bash" >"$tmpdir/bin/bash"
cat >>"$tmpdir/bin/bash" <<'EOF'
set -euo pipefail

script="$1"
shift

case "$script" in
  */preflight-switch.sh)
    printf 'preflight:%s %s\n' "$1" "$2" >>"$TEST_LOG_DIR/preflight.log"
    ;;
  */resolve-host.sh)
    printf 'resolve:%s %s %s\n' "$1" "$2" "$3" >>"$TEST_LOG_DIR/resolve.log"
    printf 'resolved-host\n'
    ;;
  *)
    exec "$REAL_BASH" "$script" "$@"
    ;;
esac
EOF
chmod +x "$tmpdir/bin/bash"

printf '#!%s\n' "$real_bash" >"$tmpdir/bin/sudo"
cat >>"$tmpdir/bin/sudo" <<'EOF'
set -euo pipefail
printf 'sudo:%s\n' "$*" >>"$TEST_LOG_DIR/cmd.log"
if [ "${1:-}" = "nixos-rebuild" ]; then
  printf 'nixos-rebuild:%s\n' "${*:2}" >>"$TEST_LOG_DIR/cmd.log"
  printf 'nixos-rebuild-output\n'
  exit 0
fi
printf 'sudo-subcommand:%s\n' "$*" >>"$TEST_LOG_DIR/cmd.log"
EOF
chmod +x "$tmpdir/bin/sudo"

printf '#!%s\n' "$real_bash" >"$tmpdir/bin/darwin-rebuild"
cat >>"$tmpdir/bin/darwin-rebuild" <<'EOF'
set -euo pipefail
printf 'darwin-rebuild:%s\n' "$*" >>"$TEST_LOG_DIR/cmd.log"
EOF
chmod +x "$tmpdir/bin/darwin-rebuild"

printf '#!%s\n' "$real_bash" >"$tmpdir/bin/nix"
cat >>"$tmpdir/bin/nix" <<'EOF'
set -euo pipefail
printf 'nix:%s\n' "$*" >>"$TEST_LOG_DIR/cmd.log"
EOF
chmod +x "$tmpdir/bin/nix"

printf '#!%s\n' "$real_bash" >"$tmpdir/bin/nom"
cat >>"$tmpdir/bin/nom" <<'EOF'
set -euo pipefail
cat >/dev/null
printf 'nom\n' >>"$TEST_LOG_DIR/cmd.log"
EOF
chmod +x "$tmpdir/bin/nom"

export TEST_LOG_DIR="$tmpdir/logs"
export REAL_BASH="$real_bash"

PATH="$tmpdir/bin:$original_path" "$real_bash" "$repo_root/nix/scripts/admin/rebuild-nixos.sh" switch zly "$repo_root"
REBUILD_PREFLIGHT=1 PATH="$tmpdir/bin:$original_path" "$real_bash" "$repo_root/nix/scripts/admin/rebuild-nixos.sh" switch zly "$repo_root"
PATH="$tmpdir/bin:$original_path" "$real_bash" "$repo_root/nix/scripts/admin/rebuild-nixos.sh" check "" "$repo_root"
PATH="$tmpdir/bin:$original_path" "$real_bash" "$repo_root/nix/scripts/admin/rebuild-darwin.sh" switch zly-mac "$repo_root"
REBUILD_PREFLIGHT=1 PATH="$tmpdir/bin:$original_path" "$real_bash" "$repo_root/nix/scripts/admin/rebuild-darwin.sh" switch zly-mac "$repo_root"
PATH="$tmpdir/bin:$original_path" "$real_bash" "$repo_root/nix/scripts/admin/rebuild-darwin.sh" check "" "$repo_root"

if ! rg -n --fixed-strings 'preflight:nixos zly' "$tmpdir/logs/preflight.log" >/dev/null; then
  echo "expected nixos safe switch to run preflight" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'resolve:nixos' "$tmpdir/logs/resolve.log" >/dev/null; then
  echo "expected nixos check without host to resolve host" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'nixos-rebuild:switch --flake path:' "$tmpdir/logs/cmd.log" >/dev/null; then
  echo "expected nixos switch rebuild command" >&2
  exit 1
fi

if ! rg -n 'nix:.*build --no-link path:' "$tmpdir/logs/cmd.log" >/dev/null; then
  echo "expected check actions to use nix build" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'darwin-rebuild:switch --flake path:' "$tmpdir/logs/cmd.log" >/dev/null; then
  echo "expected darwin switch rebuild command" >&2
  exit 1
fi

if [ "$(rg -c --fixed-strings 'preflight:nixos zly' "$tmpdir/logs/preflight.log")" -ne 1 ] || \
  [ "$(rg -c --fixed-strings 'preflight:darwin zly-mac' "$tmpdir/logs/preflight.log")" -ne 1 ]; then
  echo "expected preflight to run only for safe switch commands" >&2
  exit 1
fi
