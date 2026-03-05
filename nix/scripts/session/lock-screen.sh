# shellcheck shell=bash
wallpaper="$HOME/.config/wallpapers/1.png"
if [ ! -f "$wallpaper" ]; then
  wallpaper=""
fi

args=(
  --font "Maple Mono NF CN"
  --font-size 26
  --indicator
  --indicator-caps-lock
  --indicator-radius 120
  --indicator-thickness 10
  --clock
  --timestr "%H:%M"
  --datestr ""
  --line-color 00000000
  --separator-color 00000000
  --inside-color @THEME_BG@cc
  --ring-color @THEME_BLUE@ff
  --text-color @THEME_FG2@ff
  --inside-clear-color @THEME_BG@cc
  --ring-clear-color @THEME_YELLOW@ff
  --text-clear-color @THEME_FG2@ff
  --inside-ver-color @THEME_BG@cc
  --ring-ver-color @THEME_GREEN@ff
  --text-ver-color @THEME_FG2@ff
  --inside-wrong-color @THEME_BG@cc
  --ring-wrong-color @THEME_RED@ff
  --text-wrong-color @THEME_RED@ff
  --key-hl-color @THEME_CYAN@ff
  --bs-hl-color @THEME_RED@ff
  --show-failed-attempts
  --show-keyboard-layout
  --scaling fill
)

if [ -n "$wallpaper" ]; then
  args+=(--image "$wallpaper")
else
  args+=(--color @THEME_BG@ff)
fi

exec swaylock -f "${args[@]}" "$@"
