#!/bin/bash
# G-layer edge focus for iTerm: jump to leftmost/rightmost tmux pane,
# or fall back to adjacent AeroSpace window if already at edge.
set -eo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

direction="$1"  # "left" or "right"
tmux=/opt/homebrew/bin/tmux

case "$direction" in
    left)  edge_var="pane_at_left";  flag="-L" ;;
    right) edge_var="pane_at_right"; flag="-R" ;;
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

tmux_q() {
    if [ -n "$session" ]; then
        $tmux display-message -t "$session" -p "$1" 2>/dev/null
    else
        $tmux display-message -p "$1" 2>/dev/null
    fi
}

tmux_select() {
    if [ -n "$session" ]; then
        $tmux select-pane -t "$session" "$1" 2>/dev/null
    else
        $tmux select-pane "$1" 2>/dev/null
    fi
}

at_edge=$(tmux_q "#{$edge_var}")
if [ "$at_edge" = "1" ]; then
    smart-focus.sh "$direction"
    app=$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null || true)
    if [ "$app" = "Google Chrome" ]; then
        /usr/local/bin/hs -c "require('chrome_tabs').landNearEdge('$direction')" 2>/dev/null &
    fi
    exit 0
fi

while [ "$(tmux_q "#{$edge_var}")" = "0" ]; do
    tmux_select "$flag"
done
