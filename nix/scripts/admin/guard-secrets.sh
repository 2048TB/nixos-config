#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

repo_root="$(enter_repo_root)"
cd "$repo_root"

# 路径级阻断：任何被 Git 跟踪/暂存的密钥路径都直接失败
forbidden_path_pattern='(^|/)\.keys/|(^|/)main\.agekey$|(^|/)id_ed25519(\.pub)?$|\.pem$|\.p12$|\.pfx$'

tracked_hits="$(git ls-files | rg -n "$forbidden_path_pattern" || true)"
if [ -n "$tracked_hits" ]; then
  echo "ERROR: forbidden secret-like files are tracked by Git:" >&2
  echo "$tracked_hits" >&2
  echo "Fix: git rm --cached <file>  (keep local file), then retry." >&2
  exit 1
fi

staged_hits="$(git diff --cached --name-only | rg -n "$forbidden_path_pattern" || true)"
if [ -n "$staged_hits" ]; then
  echo "ERROR: forbidden secret-like files are staged:" >&2
  echo "$staged_hits" >&2
  echo "Fix: git restore --staged <file>, then retry." >&2
  exit 1
fi

# 内容级阻断：拦截常见私钥内容（仅检查暂存内容）
if git diff --cached --name-only | grep -q .; then
  while IFS= read -r file; do
    if [ "$file" = "nix/scripts/admin/guard-secrets.sh" ] || [ "$file" = "nix/scripts/admin/common.sh" ]; then
      continue
    fi
    if git show ":$file" 2>/dev/null | rg -n --ignore-case 'BEGIN (OPENSSH|RSA|EC|DSA|PGP) PRIVATE KEY|AGE-SECRET-KEY-1' >/dev/null; then
      echo "ERROR: staged file contains private key material: $file" >&2
      echo "Fix: git restore --staged \"$file\" and remove secret content." >&2
      exit 1
    fi
  done < <(git diff --cached --name-only)
fi

echo "secret-guard: OK"
