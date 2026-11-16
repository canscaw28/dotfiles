#!/bin/bash
# Bindings for the mouse-select key table, which tmux.conf enters when a mouse
# selection is released. It only lasts for the next key: that key leaves copy
# mode (dropping the highlight) and goes on to the shell, so typing after a
# selection works without Escape first. Keys left out fall through to copy mode.
# Each key reaches bind as its own argument, so tmux never parses it as syntax.
bind() { tmux bind -T mouse-select "$1" send -X cancel '\;' send-keys "${@:2}"; }

for ((c = 33; c < 127; c++)); do
    k=$(printf "\\$(printf %03o "$c")")
    bind "$k" -l -- "$k"
done
bind Space -l ' '
for k in Enter BSpace Tab Up Down Left Right C-a C-c C-d C-e C-l C-r C-u C-w; do
    bind "$k" "$k"
done
