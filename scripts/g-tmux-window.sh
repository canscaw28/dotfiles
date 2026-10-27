#!/bin/bash
# G-layer tmux windows for iTerm, mirroring Chrome's tab keys: U/I switch to the
# previous/next window, G+F+U/I move the pane there and follow it, and
# backslash breaks the pane out into a new window (Chrome: detach tab).
# semicolon closes the pane after tmux's own y/n prompt; comma and period
# split it side by side and stacked.
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
    # The same y/n prompt as prefix+x, shown in the front iTerm window.
    # In the current pane's directory, unlike prefix+% and prefix+".
    split-h|split-v)
        [ "$action" = split-h ] && dir="-h" || dir="-v"
        pane=$($tmux display -p -t "$session:" '#{pane_id}')
        # A new pane inherits this script's environment, which is Karabiner's
        # near-empty one (no nvm on PATH, so no node or claude). Take tmux's
        # global environment instead, as a split from inside tmux would.
        eval "$($tmux show-environment -g -s)"
        $tmux split-window "$dir" -t "$pane" -c "$($tmux display -p -t "$pane" '#{pane_current_path}')"
        ;;
    # The pane is named up front: a bare kill-pane run from outside tmux hits
    # the most recent session's pane, not this window's.
    close)
        pane=$($tmux display -p -t "$session:" '#{pane_id}')
        $tmux confirm-before -t "$itty" -p "kill-pane #P? (y/n)" "kill-pane -t $pane"
        ;;
    *) exit 1 ;;
esac
