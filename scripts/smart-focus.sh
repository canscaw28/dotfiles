#!/bin/bash
# Focus in a direction, crossing monitor boundaries when at the edge.
# Only crosses to a monitor that's physically in the requested direction.
direction="$1"

# Try to focus within the current workspace
BEFORE=$(aerospace list-windows --focused --format '%{window-id}')
aerospace focus "$direction"
AFTER=$(aerospace list-windows --focused --format '%{window-id}')

# If focus didn't change, we're at the workspace boundary —
# try the adjacent monitor in this direction
# (no --wrap-around, so nothing happens if no monitor exists there)
if [ "$BEFORE" = "$AFTER" ]; then
    aerospace focus-monitor "$direction"
fi
