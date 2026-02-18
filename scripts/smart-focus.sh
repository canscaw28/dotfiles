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

case "$direction" in
    right) opposite="left" ;;
    left)  opposite="right" ;;
    up)    opposite="down" ;;
    down)  opposite="up" ;;
esac

# Try to focus within the current workspace
BEFORE=$(aerospace list-windows --focused --format '%{window-id}')
aerospace focus "$direction"
AFTER=$(aerospace list-windows --focused --format '%{window-id}')

if [ "$BEFORE" != "$AFTER" ]; then
    aerospace move-mouse window-lazy-center 2>/dev/null || true
    /usr/local/bin/hs -c "require('focus_border').flash()" 2>/dev/null &
    exit 0  # Moved within workspace
fi

# At boundary — cross to adjacent monitor (no --wrap-around, so
# nothing happens if no monitor exists in this direction)
aerospace focus-monitor "$direction" 2>/dev/null || exit 0

# Navigate to the edge closest to where we came from
# (e.g., moving right → leftmost window on new monitor)
while true; do
    BEFORE=$(aerospace list-windows --focused --format '%{window-id}')
    aerospace focus "$opposite" 2>/dev/null || break
    AFTER=$(aerospace list-windows --focused --format '%{window-id}')
    [ "$BEFORE" = "$AFTER" ] && break
done
aerospace move-mouse window-lazy-center 2>/dev/null || aerospace move-mouse monitor-lazy-center 2>/dev/null
/usr/local/bin/hs -c "require('focus_border').flash()" 2>/dev/null &

# Guard against Chrome's makeKeyAndOrderFront stealing focus
GUARD_WID=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)
[[ -n "$GUARD_WID" ]] && ~/.local/bin/focus-guard.sh "$GUARD_WID" &
