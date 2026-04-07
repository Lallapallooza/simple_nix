#!/bin/sh
# Toggle current workspace layout between dwindle and master
WS=$(hyprctl activeworkspace -j | jq -r '.id')
LAYOUT=$(hyprctl activeworkspace -j | jq -r '.tiledLayout')

if [ "$LAYOUT" = "dwindle" ]; then
    hyprctl keyword workspace "$WS, layout:master"
    notify-send -t 1500 -h string:x-canonical-private-synchronous:layout "Layout: Master" "Workspace $WS"
else
    hyprctl keyword workspace "$WS, layout:dwindle"
    notify-send -t 1500 -h string:x-canonical-private-synchronous:layout "Layout: Dwindle" "Workspace $WS"
fi
