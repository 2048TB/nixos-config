#!/bin/sh
set -eu

exec swaylock \
  --daemonize \
  --clock \
  --indicator \
  --color @THEME_BG@ \
  --inside-color @THEME_BG1@cc \
  --ring-color @THEME_BLUE@ff \
  --key-hl-color @THEME_CYAN@ff \
  --line-color @THEME_BG3@ff \
  --separator-color @THEME_BG3@ff \
  --text-color @THEME_FG@ff
