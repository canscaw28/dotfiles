#!/bin/bash
# Workspace operations helper for AeroSpace
# Called from Karabiner-Elements shell_command via T layer
#
# Usage: ws.sh <operation> [workspace]
# Operations:
#   focus       Switch to workspace on the currently focused monitor
#   focus-1     Focus workspace on monitor 1
#   focus-2     Focus workspace on monitor 2 (falls back to monitor 1)
#   focus-3     Focus workspace on monitor 3 (falls back to monitor 1)
#   focus-4     Focus workspace on monitor 4 (falls back to monitor 1)
#   move        Move focused window to workspace (stay on current)
#   move-focus  Move focused window to workspace, follow it on current monitor
#   swap        Swap current workspace with selected workspace between monitors
#   swap-follow Swap workspaces, then focus the selected workspace
#   swap-monitors  Swap workspaces between current and next monitor
#   move-monitor   Move focused window to next monitor
#   move-monitor-focus  Move focused window to next monitor and follow
#   move-monitor-yank   Move focused window to next monitor, yank that workspace back
#   swap-windows   Swap all windows between focused workspace and target workspace
#   push-windows   Move all windows from focused workspace to target workspace
#   pull-windows   Pull all windows from target workspace to focused workspace

# Karabiner shell_command runs with minimal PATH; ensure homebrew is available
export PATH="/opt/homebrew/bin:$PATH"

set -euo pipefail

# Prevent concurrent aerospace operations (swap is multi-step and can't be
# interrupted). Other scripts (smart-focus.sh, smart-move.sh) also check this.
# If the lock holder is dead, force-remove to prevent permanent lockout.
LOCKFILE="/tmp/aerospace-lock.pid"
acquire_lock() {
    if (set -o noclobber; echo $$ > "$LOCKFILE") 2>/dev/null; then
        return 0
    fi
    # Lock exists — check if holder is alive
    local holder
    holder=$(<"$LOCKFILE" 2>/dev/null) || { rm -f "$LOCKFILE"; return 1; }
    if ! kill -0 "$holder" 2>/dev/null; then
        rm -f "$LOCKFILE"
        return 1  # Stale lock removed, caller should retry
    fi
    return 1  # Lock held by live process
}
acquire_lock || acquire_lock || exit 0
trap 'rm -f "$LOCKFILE"' EXIT

OP="$1"
WS="${2:-}"

resolve_monitor() {
    local target=$1
    local monitors
    monitors=($(aerospace list-monitors --format '%{monitor-id}'))
    for mon in "${monitors[@]}"; do
        if [[ "$mon" == "$target" ]]; then
            echo "$target"
            return
        fi
    done
    echo "1"
}

next_monitor() {
    local current="$1"
    local monitors
    monitors=($(aerospace list-monitors --format '%{monitor-id}'))
    local count=${#monitors[@]}
    for i in "${!monitors[@]}"; do
        if [[ "${monitors[$i]}" == "$current" ]]; then
            echo "${monitors[$(( (i + 1) % count ))]}"
            return
        fi
    done
}

# Find which monitor a workspace is visible on (empty if not visible on any).
visible_on_monitor() {
    local ws="$1"
    local monitors
    monitors=($(aerospace list-monitors --format '%{monitor-id}'))
    for mon in "${monitors[@]}"; do
        if [[ "$(aerospace list-workspaces --monitor "$mon" --visible)" == "$ws" ]]; then
            echo "$mon"
            return
        fi
    done
}

# Place the ~ buffer workspace on a specific monitor.
# ~ always creates on mon1; if a different monitor is needed, move it there.
place_buffer_on() {
    local mon="$1"
    aerospace workspace "$BUFFER_WS"; sleep 0.05
    if [[ "$mon" != "1" ]]; then
        aerospace move-workspace-to-monitor "$mon"; sleep 0.05
    fi
}

# Focus a workspace on a specific monitor.
# summon-workspace only works for hidden workspaces — for a workspace that's
# already visible on another monitor, it just redirects focus there and picks
# a random fallback for the source monitor. This helper detects that case and
# yanks the workspace to the target, leaving ~ on the source monitor.
focus_ws_on_monitor() {
    local target_mon="$1" ws="$2"
    local ws_mon buf_mon
    ws_mon=$(visible_on_monitor "$ws")

    if [[ "$ws_mon" == "$target_mon" ]]; then
        # Already on the target monitor, just focus it
        aerospace focus-monitor "$target_mon"
        return
    fi

    if [[ -z "$ws_mon" ]]; then
        # Hidden workspace — summon works correctly for these
        aerospace focus-monitor "$target_mon"; sleep 0.05
        aerospace summon-workspace "$ws"
        return
    fi

    # ws is visible on ws_mon, want it on target_mon, leave ~ on ws_mon.
    buf_mon=$(visible_on_monitor "$BUFFER_WS")

    if [[ "$buf_mon" == "$target_mon" ]]; then
        # ~ occupies our target from a previous yank. Move ws there directly
        # (replaces ~, which gets GC'd). Then put fresh ~ on ws_mon.
        aerospace focus-monitor "$ws_mon"; sleep 0.05
        aerospace move-workspace-to-monitor "$target_mon"; sleep 0.05
        place_buffer_on "$ws_mon"
        aerospace workspace "$ws"
    else
        # Reclaim stale ~ to mon1 if it's stranded on another monitor (3+ monitors).
        if [[ -n "$buf_mon" && "$buf_mon" != "1" ]]; then
            aerospace focus-monitor "$buf_mon"; sleep 0.05
            aerospace move-workspace-to-monitor 1; sleep 0.05
        fi
        # Place ~ on ws_mon to hide ws, then summon ws to target.
        place_buffer_on "$ws_mon"
        aerospace focus-monitor "$target_mon"; sleep 0.05
        aerospace summon-workspace "$ws"
    fi
}

# Swap two workspaces between monitors using summon-workspace.
# Args: $1=workspace_a $2=dest_monitor_a $3=workspace_b $4=dest_monitor_b
# ws_a starts on mon_b (the focused monitor), ws_b starts on mon_a.
#
# Uses ~ as an empty buffer workspace to avoid flashing existing workspaces
# during the swap. AeroSpace creates new workspaces on monitor 1, so ~ always
# lands there. summon-workspace pulls hidden workspaces to the focused monitor
# without disrupting the source monitor's visible workspace.
#
# AeroSpace occasionally drops commands in rapid succession, so swaps are
# verified and retried with a longer delay if needed.
BUFFER_WS='~'

swap_workspaces() {
    local ws_a="$1" mon_a="$2" ws_b="$3" mon_b="$4"

    # ~ buffer always lands on mon1, hiding whatever is visible there.
    # Determine which workspace is on mon1 vs the other monitor.
    local ws_on_1 ws_on_other other_mon
    if [[ "$mon_a" == "1" ]]; then
        ws_on_1="$ws_b"       # ws_b is on mon_a=1
        ws_on_other="$ws_a"   # ws_a is on mon_b
        other_mon="$mon_b"
    else
        ws_on_1="$ws_a"       # ws_a is on mon_b=1
        ws_on_other="$ws_b"   # ws_b is on mon_a
        other_mon="$mon_a"
    fi

    local D=0.05
    local attempt
    for attempt in 1 2; do
        # 1. Create ~ on mon1, hiding ws_on_1. Focus moves to mon1.
        aerospace workspace "$BUFFER_WS";  sleep "$D"
        # 2. Focus the other monitor, then summon ws_on_1 (hidden on mon1) there.
        aerospace focus-monitor "$other_mon";  sleep "$D"
        aerospace summon-workspace "$ws_on_1"; sleep "$D"
        # 3. Focus mon1 (showing ~), then summon ws_on_other (hidden on other mon).
        aerospace focus-monitor 1;             sleep "$D"
        aerospace summon-workspace "$ws_on_other"
        # 4. Focus back to the original monitor showing ws_b.
        aerospace workspace "$ws_b"

        # Verify: check both monitors show the expected workspaces
        local actual_a actual_b
        actual_a=$(aerospace list-workspaces --monitor "$mon_a" --visible)
        actual_b=$(aerospace list-workspaces --monitor "$mon_b" --visible)
        if [[ "$actual_a" == "$ws_a" && "$actual_b" == "$ws_b" ]]; then
            return 0
        fi
        # Failed — increase delay and retry
        D=0.1
    done
}

case "$OP" in
    focus)
        focus_ws_on_monitor "$(aerospace list-monitors --focused --format '%{monitor-id}')" "$WS"
        ;;
    focus-1)
        focus_ws_on_monitor "$(resolve_monitor 1)" "$WS"
        ;;
    focus-2)
        focus_ws_on_monitor "$(resolve_monitor 2)" "$WS"
        ;;
    focus-3)
        focus_ws_on_monitor "$(resolve_monitor 3)" "$WS"
        ;;
    focus-4)
        focus_ws_on_monitor "$(resolve_monitor 4)" "$WS"
        ;;
    move)
        aerospace move-node-to-workspace "$WS"
        ;;
    move-focus)
        # Move window to workspace, then pull that workspace to current monitor.
        CURRENT_MON=$(aerospace list-monitors --focused --format '%{monitor-id}')
        aerospace move-node-to-workspace "$WS"
        focus_ws_on_monitor "$CURRENT_MON" "$WS"
        ;;
    swap)
        # Swap current workspace with selected workspace between monitors.
        # Focus stays on current monitor (now showing the target workspace).
        CURRENT_WS=$(aerospace list-workspaces --focused)
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')
        TARGET_MONITOR=$(visible_on_monitor "$WS")

        if [ -n "$TARGET_MONITOR" ] && [ "$TARGET_MONITOR" != "$CURRENT_MONITOR" ]; then
            swap_workspaces "$CURRENT_WS" "$TARGET_MONITOR" "$WS" "$CURRENT_MONITOR"
        fi
        ;;
    swap-follow)
        # Swap workspaces between monitors, then focus the selected workspace.
        CURRENT_WS=$(aerospace list-workspaces --focused)
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')
        TARGET_MONITOR=$(visible_on_monitor "$WS")

        if [ -n "$TARGET_MONITOR" ] && [ "$TARGET_MONITOR" != "$CURRENT_MONITOR" ]; then
            swap_workspaces "$CURRENT_WS" "$TARGET_MONITOR" "$WS" "$CURRENT_MONITOR"
        fi
        # Follow: focus the selected workspace (now on current monitor)
        aerospace workspace "$WS"
        ;;
    move-monitor)
        # Move focused window to the next monitor's visible workspace
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')
        NEXT_MONITOR=$(next_monitor "$CURRENT_MONITOR")
        NEXT_WS=$(aerospace list-workspaces --monitor "$NEXT_MONITOR" --visible)
        aerospace move-node-to-workspace "$NEXT_WS"
        ;;
    move-monitor-focus)
        # Move focused window to next monitor and follow it
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')
        NEXT_MONITOR=$(next_monitor "$CURRENT_MONITOR")
        NEXT_WS=$(aerospace list-workspaces --monitor "$NEXT_MONITOR" --visible)
        aerospace move-node-to-workspace "$NEXT_WS"
        aerospace workspace "$NEXT_WS"
        ;;
    move-monitor-yank)
        # Move window to next monitor, then yank that workspace to current monitor
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')
        NEXT_MONITOR=$(next_monitor "$CURRENT_MONITOR")
        NEXT_WS=$(aerospace list-workspaces --monitor "$NEXT_MONITOR" --visible)
        aerospace move-node-to-workspace "$NEXT_WS"
        focus_ws_on_monitor "$CURRENT_MONITOR" "$NEXT_WS"
        ;;
    swap-windows)
        # Swap all windows between focused workspace and target workspace
        CURRENT_WS=$(aerospace list-workspaces --focused)
        CURRENT_WIDS=$(aerospace list-windows --workspace "$CURRENT_WS" --format '%{window-id}')
        TARGET_WIDS=$(aerospace list-windows --workspace "$WS" --format '%{window-id}')
        for wid in $CURRENT_WIDS; do
            aerospace move-node-to-workspace --window-id "$wid" "$WS"
        done
        for wid in $TARGET_WIDS; do
            aerospace move-node-to-workspace --window-id "$wid" "$CURRENT_WS"
        done
        aerospace workspace "$CURRENT_WS"
        ;;
    push-windows)
        # Move all windows from focused workspace to target workspace
        CURRENT_WS=$(aerospace list-workspaces --focused)
        WINDOW_IDS=$(aerospace list-windows --workspace "$CURRENT_WS" --format '%{window-id}')
        for wid in $WINDOW_IDS; do
            aerospace move-node-to-workspace --window-id "$wid" "$WS"
        done
        aerospace workspace "$CURRENT_WS"
        ;;
    pull-windows)
        # Pull all windows from target workspace to focused workspace
        CURRENT_WS=$(aerospace list-workspaces --focused)
        WINDOW_IDS=$(aerospace list-windows --workspace "$WS" --format '%{window-id}')
        for wid in $WINDOW_IDS; do
            aerospace move-node-to-workspace --window-id "$wid" "$CURRENT_WS"
        done
        ;;
    swap-monitors)
        # Swap workspaces between current and next monitor (wraps for >2)
        # Focus stays on current monitor (now showing the other workspace).
        CURRENT_WS=$(aerospace list-workspaces --focused)
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')
        # For 2-monitor setups, inline the other monitor ID to save a command.
        if [[ "$CURRENT_MONITOR" == "1" ]]; then NEXT_MONITOR=2; else NEXT_MONITOR=1; fi
        NEXT_WS=$(aerospace list-workspaces --monitor "$NEXT_MONITOR" --visible)
        swap_workspaces "$CURRENT_WS" "$NEXT_MONITOR" "$NEXT_WS" "$CURRENT_MONITOR"
        ;;
    *)
        echo "ws.sh: unknown operation '$OP'" >&2
        exit 1
        ;;
esac

# Show workspace notification overlay
NOTIFY_WS="$WS"
NOTIFY_MON=$(aerospace list-monitors --focused --format '%{monitor-id}' 2>/dev/null)
case "$OP" in
    focus-[1-4])         NOTIFY_MON="${OP##focus-}" ;;
    swap-monitors)       NOTIFY_WS="$NEXT_WS"; NOTIFY_MON="$CURRENT_MONITOR" ;;
    move-monitor|move-monitor-focus) NOTIFY_WS="$NEXT_WS"; NOTIFY_MON="$NEXT_MONITOR" ;;
    move-monitor-yank) NOTIFY_WS="$NEXT_WS"; NOTIFY_MON="$CURRENT_MONITOR" ;;
esac
if [[ -n "$NOTIFY_WS" ]]; then
    /usr/local/bin/hs -c "require('ws_notify').show('$NOTIFY_WS', ${NOTIFY_MON:-0})" 2>/dev/null &
fi

# Move mouse to focused window (replaces on-focus-changed callback which
# interferes with multi-step swap operations)
aerospace move-mouse window-lazy-center 2>/dev/null || true

# Flash border around focused window to track movement (skip for focus — grid provides feedback)
if [[ "$OP" != "focus" ]]; then
    /usr/local/bin/hs -c "require('focus_border').flash()" 2>/dev/null &
fi

# Refresh workspace grid overlay if visible
/usr/local/bin/hs -c "require('ws_grid').showGrid()" 2>/dev/null &

# Save window state after every operation (for restore on restart)
~/.local/bin/save-ws-state.sh &
