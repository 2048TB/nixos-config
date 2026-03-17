# shellcheck shell=bash
wallpaperDir="$HOME/.config/wallpapers"
wallpaper="$wallpaperDir/1.png"
runtimeDir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
wallpaperStateFile="$runtimeDir/swaybg-current-wallpaper"

randomWallpaper="$(
  find "$wallpaperDir" -maxdepth 1 \
    \( -type f -o -type l \) \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \) \
  | shuf \
  | head -n 1
)"
if [ -n "$randomWallpaper" ]; then
  wallpaper="$randomWallpaper"
fi

if [ -f "$wallpaper" ]; then
  printf '%s\n' "$wallpaper" > "$wallpaperStateFile"
else
  rm -f "$wallpaperStateFile"
fi

exec swaybg -i "$wallpaper" -m fill
