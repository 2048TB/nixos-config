# shellcheck shell=bash
exec wlogout \
  --protocol layer-shell \
  --no-span \
  --buttons-per-row 6 \
  --column-spacing 12 \
  --row-spacing 12 \
  --margin-top 330 \
  --margin-bottom 330 \
  -l "$HOME/.config/wlogout/layout" \
  -C "$HOME/.config/wlogout/style.css" \
  "$@"
