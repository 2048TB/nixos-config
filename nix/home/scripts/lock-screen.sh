# shellcheck shell=bash
wallpaper="$HOME/.config/wallpapers/1.png"
if [ ! -f "$wallpaper" ]; then
  wallpaper=""
fi

args=(
  --font "Maple Mono NF CN"
  --font-size 22
  --clock
  --timestr "%H:%M"
  --datestr "%Y-%m-%d  %A"
  --indicator
  --indicator-idle-visible
  --indicator-caps-lock
  --indicator-radius 115
  --indicator-thickness 10
  --line-color 00000000
  --separator-color 00000000
  --inside-color 1e1e2ee6
  --ring-color 89b4faff
  --text-color e2e8ffff
  --inside-clear-color 1e1e2ee6
  --ring-clear-color f9e2afff
  --text-clear-color e2e8ffff
  --inside-ver-color 1e1e2ee6
  --ring-ver-color a6e3a1ff
  --text-ver-color e2e8ffff
  --inside-wrong-color 1e1e2ee6
  --ring-wrong-color f38ba8ff
  --text-wrong-color e2e8ffff
  --key-hl-color a6e3a1ff
  --bs-hl-color f38ba8ff
  --layout-text-color bac2deff
  --grace 2
  --fade-in 0.2
  --effect-blur 7x4
  --effect-vignette 0.55:0.55
  --effect-pixelate 3
  --show-failed-attempts
  --show-keyboard-layout
  --ignore-empty-password
  --scaling fill
)

if [ -n "$wallpaper" ]; then
  args+=(--image "$wallpaper")
else
  args+=(--screenshots --color 1a1b26ff)
fi

exec swaylock -f "${args[@]}" "$@"
