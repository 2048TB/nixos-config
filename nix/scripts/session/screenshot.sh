# shellcheck shell=bash
mode="${1:-full}"
dir="${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$dir"
path="$dir/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"

case "$mode" in
  full)
    grim - | tee "$path" | wl-copy --type image/png
    ;;
  area)
    region="$(slurp)" || exit 0
    [ -n "$region" ] || exit 0
    grim -g "$region" - | tee "$path" | wl-copy --type image/png
    ;;
  *)
    exit 1
    ;;
esac
