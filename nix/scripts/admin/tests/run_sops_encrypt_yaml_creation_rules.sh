#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../../.." && pwd)"

# shellcheck disable=SC1091
source "$repo_root/nix/scripts/admin/common.sh"

tmp_target="$repo_root/secrets/.tmp-run-sops-encrypt.yaml"
trap 'rm -f "$tmp_target"' EXIT

run_sops_encrypt_yaml \
  "age1kyy6rdrj2fnh5zva5n8uah7v8lhx2axtyywhnj7grhfh5230534qccqcwh" \
  "$tmp_target" <<'EOF'
value: test
EOF

test -s "$tmp_target"
rg -q '^sops:' "$tmp_target"
