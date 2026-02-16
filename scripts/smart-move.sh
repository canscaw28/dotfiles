#!/bin/bash
# Move window in a direction, crossing monitor boundaries when at the edge.
# Prevent concurrent aerospace operations (shared with ws.sh, smart-focus.sh)
LOCKFILE="/tmp/aerospace-lock.pid"
acquire_lock() {
    if (set -o noclobber; echo $$ > "$LOCKFILE") 2>/dev/null; then return 0; fi
    local holder; holder=$(<"$LOCKFILE" 2>/dev/null) || { rm -f "$LOCKFILE"; return 1; }
    kill -0 "$holder" 2>/dev/null && return 1
    rm -f "$LOCKFILE"; return 1
}
acquire_lock || acquire_lock || exit 0
trap 'rm -f "$LOCKFILE"' EXIT

direction="$1"
case "$direction" in
    right) opposite="left" ;;
    left)  opposite="right" ;;
    up)    opposite="down" ;;
    down)  opposite="up" ;;
esac

root_layout=$(aerospace list-windows --focused --format '%{workspace-root-container-layout}')

# Try to move within the current workspace
if aerospace move --boundaries-action fail "$direction" 2>/dev/null; then
    sleep 0.01 && aerospace move-mouse window-force-center
    exit 0
fi

# Cross-axis moves (e.g., up/down in h_tiles) wrap within the workspace
is_cross_axis=false
case "$root_layout" in
    h_tiles|h_accordion)
        [[ "$direction" == "up" || "$direction" == "down" ]] && is_cross_axis=true
        ;;
    v_tiles|v_accordion)
        [[ "$direction" == "left" || "$direction" == "right" ]] && is_cross_axis=true
        ;;
esac

if $is_cross_axis; then
    aerospace move "$direction"
    sleep 0.01 && aerospace move-mouse window-force-center
    exit 0
fi

# At boundary in the same axis — cross to adjacent monitor
if ! aerospace move-node-to-monitor "$direction" --focus-follows-window 2>/dev/null; then
    exit 0  # No monitor in that direction
fi

# Position window at the entering edge (moving right → leftmost position, etc.)
while aerospace move --boundaries-action fail "$opposite" 2>/dev/null; do :; done
aerospace move-mouse window-force-center
