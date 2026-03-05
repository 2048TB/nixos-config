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
  # Catppuccin Mocha palette
  --inside-color 1e1e2ecc
  --ring-color 89b4faff
  --text-color cdd6f4ff
  --inside-clear-color 1e1e2ecc
  --ring-clear-color f9e2afff
  --text-clear-color cdd6f4ff
  --inside-ver-color 1e1e2ecc
  --ring-ver-color a6e3a1ff
  --text-ver-color cdd6f4ff
  --inside-wrong-color 1e1e2ecc
  --ring-wrong-color f38ba8ff
  --text-wrong-color f38ba8ff
  --key-hl-color b4befeff
  --bs-hl-color f38ba8ff
  --show-failed-attempts
  --show-keyboard-layout
  --scaling fill
)

if [ -n "$wallpaper" ]; then
  args+=(--image "$wallpaper")
else
  args+=(--color 11111bff)
fi

exec swaylock -f "${args[@]}" "$@"
