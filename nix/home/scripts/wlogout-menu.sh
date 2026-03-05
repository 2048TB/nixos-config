# shellcheck shell=bash
exec wlogout \
  --protocol layer-shell \
  --no-span \
  --buttons-per-row 3 \
  --column-spacing 18 \
  --row-spacing 18 \
  -l "$HOME/.config/wlogout/layout" \
  -C "$HOME/.config/wlogout/style.css" \
  "$@"
