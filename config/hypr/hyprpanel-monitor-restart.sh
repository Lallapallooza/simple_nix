#!/usr/bin/env bash
# Reload HyprPanel when a monitor reappears.
#
# When a display sleeps/disconnects and comes back, HyprPanel loses its monitor
# reference and falls back to the default layout (the config on disk is never
# touched). This is an unfixed upstream bug -- HyprPanel issues #1079, #1118,
# #1182, rooted in the astal GDK/Hyprland monitor-id mismatch (Aylur/ags#363).
# Reloading rebinds the bar to the live monitor, which is the manual fix users
# already do by hand.
#
# Event-driven and idle: this blocks on Hyprland's event socket and only wakes
# on a monitor event, so it costs nothing while nothing happens.

sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

socat -u "UNIX-CONNECT:$sock" - 2>/dev/null | while read -r event; do
  case "$event" in
    monitoradded*)
      sleep 1   # let Hyprland settle the new output before the bar attaches
      hyprpanel -q 2>/dev/null
      hyprctl dispatch exec hyprpanel
      ;;
  esac
done
