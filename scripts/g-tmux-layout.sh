#!/bin/bash
# G+F layout keys for iTerm: resize and re-arrange tmux panes, mirroring the
# T layer's window keys (-/= resize, P toggle tiles, N balance). Falls back to
# the AeroSpace equivalent when the front iTerm window isn't running tmux.
set -eo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

action="$1"
tmux=/opt/homebrew/bin/tmux

# Resolve tmux session from the frontmost iTerm2 window's TTY
# (cache maintained by Hammerspoon's iterm_tracker).
session=""
itty=$(cat /tmp/iterm-front-tty 2>/dev/null || true)
if [ -n "$itty" ]; then
    session=$($tmux list-clients -F '#{client_tty} #{client_session}' 2>/dev/null \
        | awk -v t="$itty" '$1==t {print $2; exit}')
fi

if [ -z "$session" ]; then
    case "$action" in
        grow)   aerospace resize smart +50 ;;
        shrink) aerospace resize smart -50 ;;
        toggle) aerospace layout tiles horizontal vertical ;;
        balance) aerospace balance-sizes ;;
    esac
    exit 0
fi

q() { $tmux display-message -t "$session:" -p "$1"; }

# Grow/shrink along each axis that has a neighbor to trade space with. A pane
# on the far edge has to move its other border, hence the direction flip.
resize() {
    local sign="$1"
    IFS=' ' read -r at_left at_right at_top at_bottom win_w win_h <<<"$(q \
        '#{pane_at_left} #{pane_at_right} #{pane_at_top} #{pane_at_bottom} #{window_width} #{window_height}')"
    local dx=$(( win_w / 20 > 2 ? win_w / 20 : 2 ))
    local dy=$(( win_h / 20 > 1 ? win_h / 20 : 1 ))
    if [ "$at_left$at_right" != "11" ]; then
        local flag=-R; [ "$at_right" = 1 ] && flag=-L
        [ "$sign" = - ] && { [ "$flag" = -R ] && flag=-L || flag=-R; }
        $tmux resize-pane -t "$session:" "$flag" "$dx"
    fi
    if [ "$at_top$at_bottom" != "11" ]; then
        local flag=-D; [ "$at_bottom" = 1 ] && flag=-U
        [ "$sign" = - ] && { [ "$flag" = -D ] && flag=-U || flag=-D; }
        $tmux resize-pane -t "$session:" "$flag" "$dy"
    fi
}

case "$action" in
    grow)   resize + ;;
    shrink) resize - ;;
    # Side by side unless already exactly that (all panes share a top edge),
    # in which case stack them.
    toggle)
        tops=$($tmux list-panes -t "$session:" -F '#{pane_top}' | sort -u | wc -l)
        if [ "$tops" -eq 1 ]; then
            $tmux select-layout -t "$session:" even-vertical
        else
            $tmux select-layout -t "$session:" even-horizontal
        fi
        ;;
    tiled)   $tmux select-layout -t "$session:" tiled ;;
    balance) $tmux select-layout -t "$session:" -E ;;
    *) exit 1 ;;
esac
