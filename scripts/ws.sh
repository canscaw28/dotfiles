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
#   swap        Swap current workspace with selected workspace between monitors
#   swap-follow Swap workspaces, then focus the selected workspace

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
        # Swap current workspace with selected workspace between monitors.
        # No explicit focus change — just rearrange monitor assignments.
        CURRENT_WS=$(aerospace list-workspaces --focused)
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')

        # Find which monitor the target workspace is on (empty if not visible)
        TARGET_MONITOR=$(aerospace list-monitors --workspace "$WS" --format '%{monitor-id}' 2>/dev/null || true)

        if [ -n "$TARGET_MONITOR" ] && [ "$TARGET_MONITOR" != "$CURRENT_MONITOR" ]; then
            # Target is on another monitor — swap the two workspaces
            aerospace move-workspace-to-monitor --workspace "$WS" "$CURRENT_MONITOR"
            aerospace move-workspace-to-monitor --workspace "$CURRENT_WS" "$TARGET_MONITOR"
        fi
        ;;
    swap-follow)
        # Swap workspaces between monitors, then focus the selected workspace.
        CURRENT_WS=$(aerospace list-workspaces --focused)
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')

        TARGET_MONITOR=$(aerospace list-monitors --workspace "$WS" --format '%{monitor-id}' 2>/dev/null || true)

        if [ -n "$TARGET_MONITOR" ] && [ "$TARGET_MONITOR" != "$CURRENT_MONITOR" ]; then
            aerospace move-workspace-to-monitor --workspace "$WS" "$CURRENT_MONITOR"
            aerospace move-workspace-to-monitor --workspace "$CURRENT_WS" "$TARGET_MONITOR"
        fi
        # Explicitly focus the selected workspace
        aerospace workspace "$WS"
        ;;
    *)
        echo "ws.sh: unknown operation '$OP'" >&2
        exit 1
        ;;
esac

# Save window state after every operation (for restore on restart)
~/.local/bin/save-ws-state.sh &
