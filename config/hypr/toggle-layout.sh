#!/bin/sh
# Toggle current workspace layout between dwindle and master
WS=$(hyprctl activeworkspace -j | jq -r '.id')
LAYOUT=$(hyprctl activeworkspace -j | jq -r '.tiledLayout')

# `hyprctl keyword` is gone with the lua config manager; workspace rules are set
# by evaluating lua instead. -r forces a state refresh after the rule change.
set_layout() {
    hyprctl -r eval "hl.workspace_rule({ workspace = \"$WS\", layout = \"$1\" })" >/dev/null
}

if [ "$LAYOUT" = "dwindle" ]; then
    set_layout master
    notify-send -t 1500 -h string:x-canonical-private-synchronous:layout "Layout: Master" "Workspace $WS"
else
    set_layout dwindle
    notify-send -t 1500 -h string:x-canonical-private-synchronous:layout "Layout: Dwindle" "Workspace $WS"
fi
