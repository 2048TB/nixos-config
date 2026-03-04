# shellcheck shell=bash
wallpaper="$HOME/.config/wallpapers/1.png"
if [ ! -f "$wallpaper" ]; then
  wallpaper=""
fi

args=(
  --font "Maple Mono NF CN"
  --font-size 22
  --indicator-idle-visible
  --indicator-caps-lock
  --indicator-radius 110
  --indicator-thickness 10
  --line-color 00000000
  --separator-color 00000000
  --inside-color 313244ee
  --ring-color 89b4faff
  --text-color cdd6f4ff
  --inside-clear-color 313244ee
  --ring-clear-color f9e2afff
  --text-clear-color cdd6f4ff
  --inside-ver-color 313244ee
  --ring-ver-color a6e3a1ff
  --text-ver-color cdd6f4ff
  --inside-wrong-color 313244ee
  --ring-wrong-color f38ba8ff
  --text-wrong-color cdd6f4ff
  --key-hl-color a6e3a1ff
  --bs-hl-color f38ba8ff
  --show-failed-attempts
  --show-keyboard-layout
  --scaling fill
)

if [ -n "$wallpaper" ]; then
  args+=(--image "$wallpaper")
else
  args+=(--color 1e1e2eff)
fi

exec swaylock -f "${args[@]}" "$@"
