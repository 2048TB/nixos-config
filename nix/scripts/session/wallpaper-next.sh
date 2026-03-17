# shellcheck shell=bash
runtimeDir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
launcherPidFile="$runtimeDir/swaybg-launcher.pid"
requestFile="$runtimeDir/swaybg-request"

printf 'next\n' > "$requestFile"

if [ ! -r "$launcherPidFile" ]; then
  exit 1
fi

launcherPid="$(<"$launcherPidFile")"
if [ -z "$launcherPid" ] || ! kill -0 "$launcherPid" 2>/dev/null; then
  exit 1
fi

kill -USR1 "$launcherPid"
