# shellcheck shell=bash
pick_temp_input() {
  local preferred="" hwmon="" input="" name=""
  for preferred in k10temp coretemp cpu_thermal x86_pkg_temp zenpower; do
    for hwmon in /sys/class/hwmon/hwmon*; do
      [ -d "$hwmon" ] || continue
      [ -r "$hwmon/name" ] || continue
      name="$(head -n 1 "$hwmon/name" 2>/dev/null || true)"
      [ "$name" = "$preferred" ] || continue
      for input in "$hwmon"/temp*_input; do
        [ -r "$input" ] || continue
        printf '%s\n' "$input"
        return 0
      done
    done
  done

  for input in /sys/class/hwmon/hwmon*/temp*_input; do
    [ -r "$input" ] || continue
    printf '%s\n' "$input"
    return 0
  done
  return 1
}

inputFile="$(pick_temp_input || true)"
[ -n "$inputFile" ] || exit 1

raw="$(head -n 1 "$inputFile" 2>/dev/null || true)"
[[ "$raw" =~ ^[0-9]+$ ]] || exit 1

tempC=$((raw / 1000))
class="normal"
icon="󰔄"
if [ "$tempC" -ge 85 ]; then
  class="critical"
  icon=""
elif [ "$tempC" -ge 75 ]; then
  class="warning"
  icon=""
fi

printf '{"text":"%s %s°C","class":"%s","tooltip":"Temperature: %s°C\\nSensor: %s"}\n' \
  "$icon" "$tempC" "$class" "$tempC" "${inputFile%/*}"
