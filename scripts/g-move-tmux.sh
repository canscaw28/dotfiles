#!/bin/bash
# G+F move for iTerm: swap tmux pane with its neighbor, fall back to moving
# the iTerm window via AeroSpace at the edge.
set -eo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

direction="$1"
tmux=/opt/homebrew/bin/tmux

case "$direction" in
    left)  edge_var="pane_at_left";   neighbor="{left-of}" ;;
    down)  edge_var="pane_at_bottom"; neighbor="{down-of}" ;;
    up)    edge_var="pane_at_top";    neighbor="{up-of}" ;;
    right) edge_var="pane_at_right";  neighbor="{right-of}" ;;
    *) exit 1 ;;
esac

# Resolve tmux session from the frontmost iTerm2 window's TTY
# (cache maintained by Hammerspoon's iterm_tracker).
session=""
itty=$(cat /tmp/iterm-front-tty 2>/dev/null || true)
if [ -n "$itty" ]; then
    session=$($tmux list-clients -F '#{client_tty} #{client_session}' 2>/dev/null \
        | awk -v t="$itty" '$1==t {print $2; exit}')
fi

at_edge=""
if [ -n "$session" ]; then
    at_edge=$($tmux display-message -t "$session:" -p "#{$edge_var}" 2>/dev/null || true)
fi
if [ "$at_edge" = "0" ]; then
    # -d keeps focus on the moved pane rather than on the slot it left.
    $tmux swap-pane -d -s "$session:" -t "$session:.$neighbor" 2>/dev/null
    exit 0
fi

# At edge or no tmux — fall back to AeroSpace window move
smart-move.sh "$direction"
