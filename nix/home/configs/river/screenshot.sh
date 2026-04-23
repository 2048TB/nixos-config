#!/bin/sh
set -eu

mode="${1:-area}"
dir="${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$dir"

timestamp="$(date '+%Y-%m-%d %H-%M-%S')"
file="$dir/Screenshot from $timestamp.png"

case "$mode" in
  area)
    selection="$(slurp)" || exit 0
    grim -g "$selection" "$file"
    ;;
  full)
    grim "$file"
    ;;
  *)
    echo "usage: $0 [area|full]" >&2
    exit 2
    ;;
esac
