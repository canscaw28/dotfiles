#!/bin/bash
# Workspace operations helper for AeroSpace
# Called from AeroSpace keybindings via Karabiner-Elements R layer
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

set -euo pipefail

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

case "$OP" in
    focus)
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')
        aerospace workspace "$WS"
        aerospace move-workspace-to-monitor --workspace "$WS" "$CURRENT_MONITOR"
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
        CURRENT_WS=$(aerospace list-workspaces --focused)
        CURRENT_MONITOR=$(aerospace list-monitors --focused --format '%{monitor-id}')
        NEXT_MONITOR=$(next_monitor "$CURRENT_MONITOR")
        NEXT_WS=$(aerospace list-workspaces --monitor "$NEXT_MONITOR" --visible)
        aerospace move-workspace-to-monitor --workspace "$CURRENT_WS" "$NEXT_MONITOR"
        aerospace move-workspace-to-monitor --workspace "$NEXT_WS" "$CURRENT_MONITOR"
        ;;
    *)
        echo "ws.sh: unknown operation '$OP'" >&2
        exit 1
        ;;
esac

# Save window state after every operation (for restore on restart)
~/.local/bin/save-ws-state.sh &
