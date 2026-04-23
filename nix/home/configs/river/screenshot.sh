#!/bin/sh
set -eu

mode="${1:-save-area}"
dir="${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$dir"

timestamp="$(date '+%Y-%m-%d %H-%M-%S')"
file="$dir/Screenshot from $timestamp.png"

case "$mode" in
  save-area)
    selection="$(slurp)" || exit 0
    grim -g "$selection" "$file"
    ;;
  save-full)
    grim "$file"
    ;;
  copy-area)
    selection="$(slurp)" || exit 0
    grim -g "$selection" - | wl-copy --type image/png
    ;;
  copy-full)
    grim - | wl-copy --type image/png
    ;;
  *)
    echo "usage: $0 [save-area|save-full|copy-area|copy-full]" >&2
    exit 2
    ;;
esac
