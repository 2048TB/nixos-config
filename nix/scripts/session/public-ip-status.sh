# shellcheck shell=bash
cacheDir="$HOME/.cache/waybar"
cacheFile="$cacheDir/public-ip"
now="$(date +%s)"
ip=""
sourceLabel=""

fetch_plain_ip() {
  local url="$1"
  wget -q --tries=1 -T 3 -O- "$url" 2>/dev/null | head -n 1 | tr -d '\r\n[:space:]' || true
}

fetch_trace_ip() {
  local url="$1"
  wget -q --tries=1 -T 3 -O- "$url" 2>/dev/null \
    | sed -n 's/^ip=//p' \
    | head -n 1 \
    | tr -d '\r\n[:space:]' || true
}

is_valid_ipv4() {
  local ip="$1"
  local o1="" o2="" o3="" o4="" extra="" octet=""

  IFS='.' read -r o1 o2 o3 o4 extra <<< "$ip"
  [ -z "$extra" ] || return 1

  for octet in "$o1" "$o2" "$o3" "$o4"; do
    [[ "$octet" =~ ^[0-9]{1,3}$ ]] || return 1
    [ "$octet" -le 255 ] || return 1
  done
}

is_valid_ip() {
  local ip="$1"
  if is_valid_ipv4 "$ip"; then
    return 0
  fi

  [[ "$ip" == *:* ]] || return 1
  [[ "$ip" =~ ^[0-9A-Fa-f:]+$ ]] || return 1
  return 0
}

for entry in \
  "https://api.ipify.org|ipify|plain" \
  "https://ifconfig.me/ip|ifconfig.me|plain" \
  "https://www.cloudflare.com/cdn-cgi/trace|cloudflare-trace|trace"; do
  url="${entry%%|*}"
  rest="${entry#*|}"
  label="${rest%%|*}"
  parser="${rest#*|}"

  case "$parser" in
    plain) candidate="$(fetch_plain_ip "$url")" ;;
    trace) candidate="$(fetch_trace_ip "$url")" ;;
    *) candidate="" ;;
  esac

  if [ -n "$candidate" ] && is_valid_ip "$candidate"; then
    ip="$candidate"
    sourceLabel="$label"
    break
  fi
done

if [ -n "$ip" ]; then
  mkdir -p "$cacheDir"
  printf '%s|%s|%s\n' "$now" "$ip" "$sourceLabel" > "$cacheFile"
  printf '{"text":"󰩠 %s","tooltip":"Public IP: %s\\nSource: %s\\nLeft: Connections GUI\\nRight: nmtui","class":"online"}\n' "$ip" "$ip" "$sourceLabel"
  exit 0
fi

if [ -r "$cacheFile" ]; then
  cachedLine="$(head -n 1 "$cacheFile" || true)"
  cachedTs="${cachedLine%%|*}"
  cachedRest="${cachedLine#*|}"
  cachedIp="${cachedRest%%|*}"
  cachedSrc="${cachedRest#*|}"

  if ! [[ "$cachedTs" =~ ^[0-9]+$ ]]; then
    cachedTs=0
  fi

  if [ "$cachedTs" -gt 0 ] && [ -n "$cachedIp" ] && is_valid_ip "$cachedIp"; then
    age=$((now - cachedTs))
    if [ "$age" -ge 0 ] && [ "$age" -le 1800 ]; then
      ageMin=$((age / 60))
      printf '{"text":"󰩠 %s","tooltip":"Public IP (cached %sm): %s\\nSource: %s\\nLeft: Connections GUI\\nRight: nmtui","class":"online"}\n' "$cachedIp" "$ageMin" "$cachedIp" "${cachedSrc:-cache}"
      exit 0
    fi
  fi
fi

printf '{"text":"IP N/A","tooltip":"Public IP unavailable\\nLeft: Connections GUI\\nRight: nmtui","class":"offline"}\n'
