#!/bin/bash
# Focus in a direction, crossing monitor boundaries when at the edge.
# After crossing, navigates to the spatially correct edge of the new
# workspace (e.g., moving right → leftmost window on the new monitor).
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

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

# Edge index for navigation after crossing monitors:
# moving right/down → want first (leftmost/topmost) window → index 0
# moving left/up    → want last (rightmost/bottommost) window → computed after crossing
edge_first=0
case "$direction" in
    right|down) edge_want="first" ;;
    left|up)    edge_want="last"  ;;
esac

# Try to focus within the current workspace (fail at boundary instead of wrapping)
if aerospace focus --boundaries-action fail "$direction" 2>/dev/null; then
    aerospace move-mouse window-lazy-center 2>/dev/null || true
    WID=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null) || WID=""
    if [ -n "$WID" ]; then
        /usr/local/bin/hs -c "require('focus_border').flashWindowId($WID)" 2>/dev/null &
    else
        /usr/local/bin/hs -c "require('focus_border').flash()" 2>/dev/null &
    fi
    exit 0
fi

# At boundary — cross to adjacent monitor (no --wrap-around, so
# nothing happens if no monitor exists in this direction)
if ! aerospace focus-monitor "$direction" 2>/dev/null; then
    /usr/local/bin/hs -c "require('focus_border').flash()" 2>/dev/null &
    exit 0
fi

# Jump directly to the edge window closest to where we came from
if [ "$edge_want" = "first" ]; then
    aerospace focus --dfs-index 0 2>/dev/null || true
else
    # --dfs-index only accepts UInt32, so compute the last index
    ws=$(aerospace list-workspaces --focused 2>/dev/null) || ws=""
    if [ -n "$ws" ]; then
        count=$(aerospace list-windows --workspace "$ws" --format '%{window-id}' 2>/dev/null | wc -l | tr -d ' ')
        if [ "$count" -gt 0 ] 2>/dev/null; then
            aerospace focus --dfs-index $((count - 1)) 2>/dev/null || true
        fi
    fi
fi
aerospace move-mouse window-lazy-center 2>/dev/null || aerospace move-mouse monitor-lazy-center 2>/dev/null
WID=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null) || WID=""
if [ -n "$WID" ]; then
    /usr/local/bin/hs -c "require('focus_border').flashWindowId($WID)" 2>/dev/null &
else
    /usr/local/bin/hs -c "require('focus_border').flash(true)" 2>/dev/null &
fi
