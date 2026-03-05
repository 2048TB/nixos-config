# shellcheck shell=bash
monthTitle="$(date '+%Y-%m')"
{
  printf '%s\n' "Calendar $monthTitle"
  cal
} | fuzzel --dmenu --prompt 'Date > ' --lines 10 >/dev/null || true
