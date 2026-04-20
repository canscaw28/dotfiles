#!/bin/bash
# Switch focus to the next monitor.
set -euo pipefail

# Karabiner shell_command runs with minimal PATH; ensure homebrew is available
export PATH="/opt/homebrew/bin:$PATH"

aerospace focus-monitor --wrap-around next
NEW_MON=$(aerospace list-monitors --focused --format '%{monitor-id}' 2>/dev/null || echo "")
/usr/local/bin/hs -c "require('ws_grid').showGrid(${NEW_MON:-nil})" 2>/dev/null &
aerospace move-mouse window-lazy-center 2>/dev/null || aerospace move-mouse monitor-lazy-center 2>/dev/null
FOCUSED_WIN=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null) || FOCUSED_WIN=""
FLASH_MON=""
[ -z "$FOCUSED_WIN" ] && FLASH_MON="true"
/usr/local/bin/hs -c "require('focus_border').flash($FLASH_MON)" 2>/dev/null &
