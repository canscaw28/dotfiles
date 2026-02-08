#!/bin/bash
# Workspace operations helper for AeroSpace
# Called from AeroSpace keybindings via Karabiner-Elements R layer
#
# Usage: ws.sh <operation> <workspace>
# Operations:
#   focus-1     Switch to workspace on monitor 1
#   focus-2     Switch to workspace on monitor 2
#   move        Move focused window to workspace (stay on current)
#   move-focus  Move focused window to workspace, follow it on current monitor
#   swap        Swap current workspace with target workspace between monitors (stay)
#   swap-follow Swap workspaces and follow your workspace to the other monitor

set -euo pipefail

OP="$1"
WS="$2"

case "$OP" in
    focus-1)
        aerospace workspace "$WS"
        aerospace move-workspace-to-monitor --workspace "$WS" 1
        ;;
    focus-2)
        aerospace workspace "$WS"
        aerospace move-workspace-to-monitor --workspace "$WS" 2
        ;;
    move)
        aerospace move-node-to-workspace "$WS"
        ;;
    move-focus)
        # Save which monitor we're on, move window, switch to workspace,
        # then bring workspace to the monitor we started on
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')
        aerospace move-node-to-workspace "$WS"
        aerospace workspace "$WS"
        aerospace move-workspace-to-monitor --workspace "$WS" "$CURRENT_MONITOR"
        ;;
    swap)
        # Swap current workspace with target workspace between monitors.
        # After swap, stay on current monitor (target workspace appears here).
        CURRENT_WS=$(aerospace list-workspaces --focused)
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')

        # Find which monitor the target workspace is on (empty if not visible)
        TARGET_MONITOR=$(aerospace list-monitors --workspace "$WS" --format '%{monitor-id}' 2>/dev/null || true)

        if [ -n "$TARGET_MONITOR" ] && [ "$TARGET_MONITOR" != "$CURRENT_MONITOR" ]; then
            # Target is visible on another monitor — perform a true swap
            aerospace move-workspace-to-monitor --workspace "$WS" "$CURRENT_MONITOR"
            aerospace move-workspace-to-monitor --workspace "$CURRENT_WS" "$TARGET_MONITOR"
            aerospace workspace "$WS"
        else
            # Target not visible or on same monitor — just switch to it
            aerospace workspace "$WS"
        fi
        ;;
    swap-follow)
        # Swap workspaces between monitors, then follow your original workspace
        # to the other monitor.
        CURRENT_WS=$(aerospace list-workspaces --focused)
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')

        TARGET_MONITOR=$(aerospace list-monitors --workspace "$WS" --format '%{monitor-id}' 2>/dev/null || true)

        if [ -n "$TARGET_MONITOR" ] && [ "$TARGET_MONITOR" != "$CURRENT_MONITOR" ]; then
            # Perform swap, then focus original workspace (now on other monitor)
            aerospace move-workspace-to-monitor --workspace "$WS" "$CURRENT_MONITOR"
            aerospace move-workspace-to-monitor --workspace "$CURRENT_WS" "$TARGET_MONITOR"
            aerospace workspace "$CURRENT_WS"
        else
            # Target not visible or on same monitor — switch to target
            aerospace workspace "$WS"
        fi
        ;;
    *)
        echo "ws.sh: unknown operation '$OP'" >&2
        exit 1
        ;;
esac

# Save window state after every operation (for restore on restart)
~/.local/bin/save-ws-state.sh &
