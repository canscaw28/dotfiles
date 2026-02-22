#!/bin/bash
# Focus in a direction, crossing monitor boundaries when at the edge.
# After crossing, navigates to the spatially correct edge of the new
# workspace (e.g., moving right → leftmost window on the new monitor).
set -euo pipefail

# Prevent concurrent aerospace operations (shared with ws.sh, smart-move.sh)
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

# DFS index for edge navigation after crossing monitors:
# moving right/down → want first (leftmost/topmost) window → index 0
# moving left/up    → want last (rightmost/bottommost) window → index -1
case "$direction" in
    right|down) edge_index=0  ;;
    left|up)    edge_index=-1 ;;
esac

# Try to focus within the current workspace (fail at boundary instead of wrapping)
if aerospace focus --boundaries-action fail "$direction" 2>/dev/null; then
    aerospace move-mouse window-lazy-center 2>/dev/null || true
    /usr/local/bin/hs -c "require('focus_border').flash()" 2>/dev/null &
    exit 0
fi

# At boundary — cross to adjacent monitor (no --wrap-around, so
# nothing happens if no monitor exists in this direction)
aerospace focus-monitor "$direction" 2>/dev/null || exit 0

# Jump directly to the edge window closest to where we came from
aerospace focus --dfs-index "$edge_index" 2>/dev/null || true
aerospace move-mouse window-lazy-center 2>/dev/null || aerospace move-mouse monitor-lazy-center 2>/dev/null
FOCUSED_WIN=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null) || FOCUSED_WIN=""
FLASH_MON=""
[ -z "$FOCUSED_WIN" ] && FLASH_MON="true"
/usr/local/bin/hs -c "require('focus_border').flash($FLASH_MON)" 2>/dev/null &
