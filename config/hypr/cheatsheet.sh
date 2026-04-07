#!/usr/bin/env bash
sed -n '/^# WORKFLOW/,/^$/p' ~/.config/hypr/user.conf \
  | grep '^#' \
  | sed 's/^#  *//' \
  | grep -v '^$' \
  | grep -v '^#$' \
  | rofi -dmenu -i -p "keybinds"
