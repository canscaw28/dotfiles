#!/bin/bash
# G-layer tmux windows for iTerm, mirroring Chrome's tab keys: U/I switch to the
# previous/next window, G+F+U/I move the pane there and follow it, and
# backslash breaks the pane out into a new window (Chrome: detach tab).
set -eo pipefail

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
[ -n "$session" ] || exit 0

case "$action" in
    prev) $tmux previous-window -t "$session" ;;
    next) $tmux next-window -t "$session" ;;
    move-prev|move-next)
        [ "$($tmux display -p -t "$session:" '#{session_windows}')" -gt 1 ] || exit 0
        [ "$action" = move-prev ] && rel="-" || rel="+"
        pane=$($tmux display -p -t "$session:" '#{pane_id}')
        # By id: the source window closes if this was its last pane.
        target=$($tmux display -p -t "$session:$rel" '#{window_id}')
        $tmux join-pane -s "$pane" -t "$target" \; select-window -t "$target"
        ;;
    break)
        [ "$($tmux display -p -t "$session:" '#{window_panes}')" -gt 1 ] || exit 0
        # Without -t the new window lands in tmux's most recent session,
        # which needn't be the front window's.
        $tmux break-pane -s "$session:" -t "$session:"
        ;;
    *) exit 1 ;;
esac
