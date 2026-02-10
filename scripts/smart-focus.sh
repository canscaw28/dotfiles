#!/bin/bash
# Focus in a direction, crossing monitor boundaries when at the edge.
# Only crosses to a monitor that's physically in the requested direction.
direction="$1"

# Try to focus within the current workspace
if aerospace focus --boundaries-action fail "$direction" 2>/dev/null; then
    exit 0
fi

# At workspace boundary — focus the adjacent monitor in this direction
# (no --wrap-around, so nothing happens if no monitor exists there)
aerospace focus-monitor "$direction"
