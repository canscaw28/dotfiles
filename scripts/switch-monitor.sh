#!/bin/bash
# Switch focus to the next monitor, preserving the source monitor's workspace.
# macOS app activation can cause the source monitor to switch workspaces when
# a different app gains focus on the target — this script detects and fixes that.
set -euo pipefail

SOURCE_MON=$(aerospace list-monitors --focused --format '%{monitor-id}')
SOURCE_WS=$(aerospace list-workspaces --focused)

aerospace focus-monitor --wrap-around next

TARGET_MON=$(aerospace list-monitors --focused --format '%{monitor-id}')

aerospace move-mouse window-lazy-center 2>/dev/null || aerospace move-mouse monitor-lazy-center 2>/dev/null
/usr/local/bin/hs -c "require('focus_border').flash(); require('ws_grid').showGrid()" 2>/dev/null &

# Restore source workspace if macOS app activation changed it
sleep 0.05
ACTUAL_SOURCE=$(aerospace list-workspaces --monitor "$SOURCE_MON" --visible 2>/dev/null)
if [[ "$ACTUAL_SOURCE" != "$SOURCE_WS" ]]; then
    aerospace focus-monitor "$SOURCE_MON" 2>/dev/null; sleep 0.05
    aerospace workspace "$SOURCE_WS" 2>/dev/null; sleep 0.05
    aerospace focus-monitor "$TARGET_MON" 2>/dev/null
    aerospace move-mouse window-lazy-center 2>/dev/null || aerospace move-mouse monitor-lazy-center 2>/dev/null
fi
