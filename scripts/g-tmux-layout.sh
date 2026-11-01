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

# Prints how the active pane's immediate split is laid out ("{" side by side,
# "[" stacked) and whether the pane is its last member, read from the
# window_layout string (e.g. "b25d,80x24,0,0{40x24,0,0,1,39x24,41,0[...]}").
# Prints nothing for a lone pane.
split_of_pane() {
    q '#{window_layout} #{pane_id}' | awk '{
        s = $1; id = substr($2, 2); sub(/^[^,]*,/, "", s); n = 0
        while (length(s)) {
            c = substr(s, 1, 1)
            if (c == "{" || c == "[") { stack[++n] = c; s = substr(s, 2); continue }
            if (c == "}" || c == "]") { n--; s = substr(s, 2); continue }
            if (c == ",") { s = substr(s, 2); continue }
            match(s, /^[0-9]+x[0-9]+,[0-9]+,[0-9]+/); s = substr(s, RLENGTH + 1)
            if (substr(s, 1, 1) != ",") continue
            s = substr(s, 2); match(s, /^[0-9]+/)
            leaf = substr(s, 1, RLENGTH); s = substr(s, RLENGTH + 1)
            if (leaf == id && n > 0) {
                next_c = substr(s, 1, 1)
                print stack[n], (next_c == "}" || next_c == "]") ? 1 : 0
                exit
            }
        }
    }'
}

# Like AeroSpace's smart resize: grow/shrink only along the pane's own split,
# trading space with its siblings there. The last pane in the split has to move
# its other border, hence the direction flip.
resize() {
    local sign="$1" split last flag amount
    read -r split last <<<"$(split_of_pane)"
    [ -n "$split" ] || return 0
    IFS=' ' read -r win_w win_h <<<"$(q '#{window_width} #{window_height}')"
    if [ "$split" = "{" ]; then
        flag=-R; [ "$last" = 1 ] && flag=-L
        [ "$sign" = - ] && { [ "$flag" = -R ] && flag=-L || flag=-R; }
        amount=$(( win_w / 20 > 2 ? win_w / 20 : 2 ))
    else
        flag=-D; [ "$last" = 1 ] && flag=-U
        [ "$sign" = - ] && { [ "$flag" = -D ] && flag=-U || flag=-D; }
        amount=$(( win_h / 20 > 1 ? win_h / 20 : 1 ))
    fi
    $tmux resize-pane -t "$session:" "$flag" "$amount"
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
