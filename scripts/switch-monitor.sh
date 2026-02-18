#!/bin/bash
# Switch focus to the next monitor.
set -euo pipefail

# Karabiner shell_command runs with minimal PATH; ensure homebrew is available
export PATH="/opt/homebrew/bin:$PATH"

aerospace focus-monitor --wrap-around next
aerospace move-mouse window-lazy-center 2>/dev/null || aerospace move-mouse monitor-lazy-center 2>/dev/null
/usr/local/bin/hs -c "require('focus_border').flash(); require('ws_grid').showGrid()" 2>/dev/null &

# Guard against Chrome's makeKeyAndOrderFront stealing focus
GUARD_WID=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)
[[ -n "$GUARD_WID" ]] && ~/.local/bin/focus-guard.sh "$GUARD_WID" &
