#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo ./scripts/create-home-snapshot.sh [label]
EOF
}

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 1
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This helper only supports Linux." >&2
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this helper as root." >&2
  exit 1
fi

label=${1:-manual}
timestamp=$(date +%Y%m%d-%H%M%S)
target_dir="/.snapshots/manual-home"
target_path="${target_dir}/${timestamp}-${label}"

test -d /home
test -d /.snapshots
test "$(findmnt -no FSTYPE /home)" = "btrfs"
test "$(findmnt -no FSTYPE /.snapshots)" = "btrfs"

install -d -m 0755 "$target_dir"
btrfs subvolume snapshot -r /home "$target_path"

echo "created readonly /home snapshot: $target_path"
