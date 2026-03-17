# shellcheck shell=bash
runtimeDir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

launch_waybar() {
  exec waybar-quiet
}

launch_if_wayland_ready() {
  if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$runtimeDir/$WAYLAND_DISPLAY" ]; then
    launch_waybar
    return 0
  fi

  for socket in "$runtimeDir"/wayland-*; do
    [ -S "$socket" ] || continue
    export WAYLAND_DISPLAY="${socket##*/}"
    launch_waybar
    return 0
  done

  return 1
}

for _ in $(seq 1 100); do
  launch_if_wayland_ready || true
  sleep 0.1
done

exit 1
