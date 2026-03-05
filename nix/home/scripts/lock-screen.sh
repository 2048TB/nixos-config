# shellcheck shell=bash
wallpaper="$HOME/.config/wallpapers/1.png"
if [ ! -f "$wallpaper" ]; then
  wallpaper=""
fi

args=(
  --font "Maple Mono NF CN"
  --font-size 24
  --indicator-idle-visible
  --indicator-caps-lock
  --indicator-radius 130
  --indicator-thickness 12
  --line-color 00000000
  --separator-color 00000000
  # Nord palette
  --inside-color 2e3440cc
  --ring-color 81a1c1ff
  --text-color eceff4ff
  --inside-clear-color 2e3440cc
  --ring-clear-color ebcb8bff
  --text-clear-color eceff4ff
  --inside-ver-color 2e3440cc
  --ring-ver-color a3be8cff
  --text-ver-color eceff4ff
  --inside-wrong-color 2e3440cc
  --ring-wrong-color bf616aff
  --text-wrong-color bf616aff
  --key-hl-color 88c0d0ff
  --bs-hl-color bf616aff
  --show-failed-attempts
  --show-keyboard-layout
  --scaling fill
)

if [ -n "$wallpaper" ]; then
  args+=(--image "$wallpaper")
else
  args+=(--color 2e3440ff)
fi

exec swaylock -f "${args[@]}" "$@"
