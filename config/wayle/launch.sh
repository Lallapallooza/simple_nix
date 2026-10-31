#!/bin/sh
# Launch a bar click's program through Hyprland, so it opens on the current
# workspace. Started by wayle directly, initial_workspace_tracking puts it on
# wayle's workspace (1).
cmd=$(printf '%s' "$*" | sed 's/\\/\\\\/g; s/"/\\"/g')
exec hyprctl eval "hl.exec_cmd(\"$cmd\")"
