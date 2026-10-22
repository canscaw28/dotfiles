#!/bin/bash
# Give a pane the lowest number no live agent pane holds, shown in its border
# label and used for its Chrome tab group. Run by the pane-title-changed hook in
# .tmux.conf when an agent starts in a pane without one. tmux's own pane ids
# only ever count up, so numbers from closed panes would never come back.
pane="$1"

panes=$(tmux list-panes -a -F '#{pane_id} #{pane_current_command} #{@num}')
used=$(awk -v p="$pane" '$1 != p && $2 ~ /^(claude|codex)/ && $3 != "" { print $3 }' <<<"$panes")

n=1
while grep -qx "$n" <<<"$used"; do n=$((n + 1)); done
tmux set -p -t "$pane" @num "$n"

# A pane whose agent exited keeps its @num; clear it there so an agent
# restarted in that pane picks again rather than showing a duplicate.
awk -v p="$pane" -v n="$n" '$1 != p && $2 !~ /^(claude|codex)/ && $3 == n { print $1 }' <<<"$panes" |
    while read -r old; do tmux set -pu -t "$old" @num; done
