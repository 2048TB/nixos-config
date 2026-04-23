#!/bin/sh
set -eu

mode="${1:-save-area}"
dir="${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
timestamp="$(date '+%Y-%m-%d %H-%M-%S')"
file="$dir/Screenshot from $timestamp.png"

usage() {
  echo "usage: $0 [save-area|save-full|copy-area|copy-full]" >&2
}

select_area() {
  slurp
}

mkdir -p "$dir"

case "$mode" in
  save-area)
    selection="$(select_area)" || exit 0
    grim -g "$selection" "$file"
    ;;
  save-full)
    grim "$file"
    ;;
  copy-area)
    selection="$(select_area)" || exit 0
    grim -g "$selection" - | wl-copy --type image/png
    ;;
  copy-full)
    grim - | wl-copy --type image/png
    ;;
  *)
    usage
    exit 2
    ;;
esac
