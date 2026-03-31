#!/bin/bash
# G-layer focus for iTerm: try tmux pane, fall back to AeroSpace window.
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

direction="$1"
tmux=/opt/homebrew/bin/tmux

case "$direction" in
    left)  edge_var="pane_at_left";   flag="-L" ;;
    down)  edge_var="pane_at_bottom"; flag="-D" ;;
    up)    edge_var="pane_at_top";    flag="-U" ;;
    right) edge_var="pane_at_right";  flag="-R" ;;
    *) exit 1 ;;
esac

# Check if tmux is running and pane is not at edge
if at_edge=$($tmux display-message -p "#{$edge_var}" 2>/dev/null) && [ "$at_edge" = "0" ]; then
    $tmux select-pane "$flag" 2>/dev/null
    exit 0
fi

# At edge or no tmux — fall back to AeroSpace window focus
smart-focus.sh "$direction"

# If we landed on a Chrome window, jump to the near-edge tab
app=$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null) || app=""
if [ "$app" = "Google Chrome" ]; then
    /usr/local/bin/hs -c "require('chrome_tabs').landNearEdge('$direction')" 2>/dev/null &
fi
