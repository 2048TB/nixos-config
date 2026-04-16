#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

usage() {
  cat <<'EOF'
usage: guard-secrets.sh [--all-tracked]

  --all-tracked   Scan all tracked repository content (periodic full scan)
EOF
}

scan_mode="staged"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --all-tracked)
      scan_mode="all-tracked"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(enter_repo_root)"
cd "$repo_root"

# 路径级阻断：任何被 Git 跟踪/暂存的密钥路径都直接失败
forbidden_path_pattern='(^|/)\.keys/|(^|/)main\.agekey$|(^|/)id_ed25519(\.pub)?$|\.pem$|\.p12$|\.pfx$'
private_key_content_pattern='BEGIN (OPENSSH|RSA|EC|DSA|PGP) PRIVATE KEY|AGE-SECRET-KEY-1'
private_key_content_pattern_ci="(?i:${private_key_content_pattern})"
credential_content_pattern='ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|sk-[A-Za-z0-9]{20,}|(?i)(api[_-]?key|token|secret|password|passwd)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_.+=-]{24,}'

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

# 内容级阻断：
# - default: 仅检查暂存内容（pre-commit）
# - --all-tracked: 检查全部 tracked 文件
list_content_scan_files() {
  if [ "$scan_mode" = "all-tracked" ]; then
    git ls-files
  else
    git diff --cached --name-only
  fi
}

mapfile -t content_scan_files < <(list_content_scan_files)
if [ "${#content_scan_files[@]}" -gt 0 ]; then
  read_file_content() {
    local file="${1:-}"
    if [ "$scan_mode" = "all-tracked" ]; then
      cat "$file"
    else
      git show ":$file"
    fi
  }

  combined_secret_pattern="$private_key_content_pattern_ci|$credential_content_pattern"

  for file in "${content_scan_files[@]}"; do
    if [ "$file" = "nix/scripts/admin/guard-secrets.sh" ] || [ "$file" = "nix/scripts/admin/common.sh" ]; then
      continue
    fi
    if read_file_content "$file" 2>/dev/null | rg -n "$combined_secret_pattern" >/dev/null; then
      if read_file_content "$file" 2>/dev/null | rg -n "$private_key_content_pattern_ci" >/dev/null; then
        if [ "$scan_mode" = "all-tracked" ]; then
          echo "ERROR: tracked file contains private key material: $file" >&2
        else
          echo "ERROR: staged file contains private key material: $file" >&2
        fi
      else
        if [ "$scan_mode" = "all-tracked" ]; then
          echo "ERROR: tracked file contains token/password-like secret material: $file" >&2
        else
          echo "ERROR: staged file contains token/password-like secret material: $file" >&2
        fi
      fi
      echo "Fix: remove secret content before commit/push." >&2
      exit 1
    fi
  done
fi

echo "secret-guard: OK"
