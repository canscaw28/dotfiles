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
    *)
        echo "ws.sh: unknown operation '$OP'" >&2
        exit 1
        ;;
esac
