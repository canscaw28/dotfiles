#!/bin/bash
# Workspace operations helper for AeroSpace
# Called from Karabiner-Elements shell_command via R layer
#
# Usage: ws.sh <operation> [workspace]
# Operations:
#   focus       Switch to workspace on the currently focused monitor
#   move        Move focused window to workspace (stay on current)
#   move-focus  Move focused window to workspace, follow it on current monitor
#   swap        Swap current workspace with selected workspace between monitors
#   swap-follow Swap workspaces, then focus the selected workspace
#   swap-monitors  Swap workspaces between current and next monitor
#   move-monitor   Move focused window to next monitor
#   move-monitor-focus  Move focused window to next monitor and follow

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
        # Move workspace to current monitor first (hidden), then focus it.
        # Avoids jitter: aerospace workspace would briefly show WS on the
        # wrong monitor before move-workspace-to-monitor pulls it back.
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')
        aerospace move-workspace-to-monitor --workspace "$WS" "$CURRENT_MONITOR"
        aerospace workspace "$WS"
        ;;
    move)
        aerospace move-node-to-workspace "$WS"
        ;;
    move-focus)
        # Move window, bring workspace to current monitor, then focus it.
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')
        aerospace move-node-to-workspace "$WS"
        aerospace move-workspace-to-monitor --workspace "$WS" "$CURRENT_MONITOR"
        aerospace workspace "$WS"
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

# Move mouse to focused window (replaces on-focus-changed callback which
# interferes with multi-step swap operations)
aerospace move-mouse window-lazy-center 2>/dev/null || true

# Save window state after every operation (for restore on restart)
~/.local/bin/save-ws-state.sh &
