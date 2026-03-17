# shellcheck shell=bash
wallpaperDir="$HOME/.config/wallpapers"
wallpaper="$wallpaperDir/1.png"
runtimeDir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
wallpaperStateFile="$runtimeDir/swaybg-current-wallpaper"
launcherPidFile="$runtimeDir/swaybg-launcher.pid"
requestFile="$runtimeDir/swaybg-request"
rotateIntervalSeconds=1800
swaybgPid=""
sleepPid=""
requestedMode="random"

persist_wallpaper_state() {
  if [ -f "$wallpaper" ]; then
    printf '%s\n' "$wallpaper" > "$wallpaperStateFile"
  else
    rm -f "$wallpaperStateFile"
  fi
}

pick_random_wallpaper() {
  local randomWallpaper=""
  randomWallpaper="$(
    find "$wallpaperDir" -maxdepth 1 \
      \( -type f -o -type l \) \
      \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \) \
    | shuf \
    | head -n 1
  )"
  if [ -n "$randomWallpaper" ]; then
    wallpaper="$randomWallpaper"
  else
    wallpaper="$wallpaperDir/1.png"
  fi
}

pick_next_wallpaper() {
  local currentWallpaper="" i=0
  local -a wallpapers=()

  mapfile -t wallpapers < <(
    find "$wallpaperDir" -maxdepth 1 \
      \( -type f -o -type l \) \
      \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \) \
      | sort
  )

  if [ "${#wallpapers[@]}" -eq 0 ]; then
    wallpaper="$wallpaperDir/1.png"
    return
  fi

  if [ -r "$wallpaperStateFile" ]; then
    currentWallpaper="$(<"$wallpaperStateFile")"
  fi

  for i in "${!wallpapers[@]}"; do
    if [ "${wallpapers[$i]}" = "$currentWallpaper" ]; then
      wallpaper="${wallpapers[$(((i + 1) % ${#wallpapers[@]}))]}"
      return
    fi
  done

  wallpaper="${wallpapers[0]}"
}

pick_wallpaper() {
  case "${1:-random}" in
    next)
      pick_next_wallpaper
      ;;
    *)
      pick_random_wallpaper
      ;;
  esac

  persist_wallpaper_state
}

stop_swaybg() {
  if [ -n "$swaybgPid" ] && kill -0 "$swaybgPid" 2>/dev/null; then
    kill "$swaybgPid"
    wait "$swaybgPid" 2>/dev/null || true
  fi
  swaybgPid=""
}

cleanup() {
  rm -f "$launcherPidFile" "$requestFile"
  if [ -n "$sleepPid" ] && kill -0 "$sleepPid" 2>/dev/null; then
    kill "$sleepPid" 2>/dev/null || true
    wait "$sleepPid" 2>/dev/null || true
  fi
  stop_swaybg
}

handle_request_signal() {
  if [ -r "$requestFile" ]; then
    requestedMode="$(<"$requestFile")"
    rm -f "$requestFile"
  else
    requestedMode="next"
  fi

  if [ -n "$sleepPid" ] && kill -0 "$sleepPid" 2>/dev/null; then
    kill "$sleepPid" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM
trap handle_request_signal USR1

printf '%s\n' "$$" > "$launcherPidFile"

while :; do
  pick_wallpaper "$requestedMode"
  requestedMode="random"
  stop_swaybg

  swaybg -i "$wallpaper" -m fill &
  swaybgPid="$!"

  sleep "$rotateIntervalSeconds" &
  sleepPid="$!"
  wait "$sleepPid" 2>/dev/null || true
  sleepPid=""
done
