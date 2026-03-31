#!/bin/bash
# G-layer edge focus for iTerm: jump to leftmost/rightmost tmux pane,
# or fall back to adjacent AeroSpace window if already at edge.
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

direction="$1"  # "left" or "right"
tmux=/opt/homebrew/bin/tmux

case "$direction" in
    left)  edge_var="pane_at_left";  flag="-L" ;;
    right) edge_var="pane_at_right"; flag="-R" ;;
    *) exit 1 ;;
esac

# If already at edge, fall back to AeroSpace window focus
at_edge=$($tmux display-message -p "#{$edge_var}" 2>/dev/null) || at_edge=""
if [ "$at_edge" = "1" ]; then
    smart-focus.sh "$direction"
    app=$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null) || app=""
    if [ "$app" = "Google Chrome" ]; then
        /usr/local/bin/hs -c "require('chrome_tabs').landNearEdge('$direction')" 2>/dev/null &
    fi
    exit 0
fi

# Jump to the edge pane
while [ "$($tmux display-message -p "#{$edge_var}" 2>/dev/null)" = "0" ]; do
    $tmux select-pane "$flag" 2>/dev/null
done
