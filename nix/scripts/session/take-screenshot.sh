#!/usr/bin/env sh

set -eu

mode="${1:-area}"
shots_dir="${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
outfile="${shots_dir}/Screenshot_${timestamp}.png"

mkdir -p "$shots_dir"

case "$mode" in
  area)
    geometry="$(slurp)"
    [ -n "$geometry" ] || exit 0
    grim -g "$geometry" "$outfile"
    ;;
  screen)
    grim "$outfile"
    ;;
  *)
    echo "unsupported screenshot mode: $mode" >&2
    exit 1
    ;;
esac

wl-copy < "$outfile"
printf '%s\n' "$outfile"
