#!/usr/bin/env bash

# 10分钟锁屏，15分钟熄屏，30分钟休眠
exec swayidle -w \
timeout 600  'swaylock -f &' \
timeout 900  'niri msg action power-off-monitors' \
resume       'niri msg action power-on-monitors' \
timeout 1800 'systemctl suspend'
