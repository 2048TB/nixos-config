#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/sops-age-key.txt" >&2
  exit 1
fi

src="$1"
dest_dir="/var/lib/sops-nix"
dest_file="$dest_dir/key.txt"

if [ ! -f "$src" ]; then
  echo "Key file not found: $src" >&2
  exit 1
fi

install -d -m 0700 "$dest_dir"
install -m 0600 "$src" "$dest_file"

echo "Installed age key to $dest_file"
echo "Make sure this machine can decrypt secrets/common.yaml before switching."
