#!/bin/sh
set -eu

wallpaper_dir="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/river"
current_file="$state_dir/current-wallpaper"
interval="${WALLPAPER_INTERVAL:-1800}"
swaybg="__SWAYBG__"
systemctl="__SYSTEMCTL__"
export PATH="__RUNTIME_PATH__:$PATH"

swaybg_pid=""
sleep_pid=""
next_requested=0

list_wallpapers() {
  find -L "$wallpaper_dir" -maxdepth 1 -type f \( \
    -iname '*.jpg' -o \
    -iname '*.jpeg' -o \
    -iname '*.png' -o \
    -iname '*.webp' \
  \) | sort
}

wallpaper_count() {
  list_wallpapers | wc -l | tr -d ' '
}

current_wallpaper() {
  if [ -r "$current_file" ]; then
    cat "$current_file"
  fi
}

random_wallpaper() {
  count="$(wallpaper_count)"
  [ "$count" -gt 0 ] || return 1
  index="$(od -An -N4 -tu4 /dev/urandom | awk -v count="$count" '{ print ($1 % count) + 1 }')"
  list_wallpapers | sed -n "${index}p"
}

next_wallpaper() {
  wallpapers="$(list_wallpapers)"
  [ -n "$wallpapers" ] || return 1

  current="$(current_wallpaper)"
  first="$(printf '%s\n' "$wallpapers" | sed -n '1p')"
  if [ -z "$current" ]; then
    printf '%s\n' "$first"
    return 0
  fi

  next="$(printf '%s\n' "$wallpapers" | awk -v current="$current" 'found { print; exit } $0 == current { found = 1 }')"
  if [ -n "$next" ]; then
    printf '%s\n' "$next"
  else
    printf '%s\n' "$first"
  fi
}

set_wallpaper() {
  file="$1"
  [ -n "$file" ] && [ -f "$file" ] || return 1

  mkdir -p "$state_dir"
  printf '%s\n' "$file" > "$current_file"

  if [ -n "$swaybg_pid" ] && kill -0 "$swaybg_pid" 2>/dev/null; then
    kill "$swaybg_pid" 2>/dev/null || true
    wait "$swaybg_pid" 2>/dev/null || true
  fi

  "$swaybg" -m fill -i "$file" &
  swaybg_pid="$!"
}

cleanup() {
  if [ -n "$sleep_pid" ]; then
    kill "$sleep_pid" 2>/dev/null || true
  fi
  if [ -n "$swaybg_pid" ] && kill -0 "$swaybg_pid" 2>/dev/null; then
    kill "$swaybg_pid" 2>/dev/null || true
    wait "$swaybg_pid" 2>/dev/null || true
  fi
}

request_next() {
  next_requested=1
  if [ -n "$sleep_pid" ]; then
    kill "$sleep_pid" 2>/dev/null || true
  fi
}

daemon() {
  trap request_next USR1
  trap cleanup INT TERM EXIT

  set_wallpaper "$(random_wallpaper)"

  while :; do
    next_requested=0
    sleep "$interval" &
    sleep_pid="$!"
    wait "$sleep_pid" 2>/dev/null || true
    sleep_pid=""

    if [ "$next_requested" -eq 1 ]; then
      set_wallpaper "$(next_wallpaper)" || true
    else
      set_wallpaper "$(random_wallpaper)" || true
    fi
  done
}

next() {
  "$systemctl" --user start wallpaper.service
  exec "$systemctl" --user kill --kill-whom=main --signal=USR1 wallpaper.service
}

case "${1:-daemon}" in
  daemon)
    daemon
    ;;
  next)
    next
    ;;
  *)
    echo "usage: $0 [daemon|next]" >&2
    exit 2
    ;;
esac
