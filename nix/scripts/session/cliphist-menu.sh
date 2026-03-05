# shellcheck shell=bash
picked="$(cliphist list | fuzzel --dmenu || true)"
[ -n "$picked" ] || exit 0
printf '%s' "$picked" | cliphist decode | wl-copy
