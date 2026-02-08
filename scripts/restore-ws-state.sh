#!/bin/bash
# Restore window-to-workspace mapping after AeroSpace restart
#
# Reads saved state from ~/.aerospace-window-state and moves windows
# back to their previous workspaces by matching on app-name and window-title.

STATE_FILE="$HOME/.aerospace-window-state"

if [ ! -f "$STATE_FILE" ]; then
    exit 0
fi

# Give AeroSpace a moment to discover all windows after startup
sleep 1

# Build lookup: "app|title" → workspace from saved state
declare -A SAVED
while IFS='|' read -r app title ws; do
    [ -z "$app" ] && continue
    SAVED["$app|$title"]="$ws"
done < "$STATE_FILE"

# Get current windows and move them to saved workspaces
while IFS='|' read -r wid app title; do
    [ -z "$wid" ] && continue
    key="$app|$title"
    if [ -n "${SAVED[$key]+x}" ]; then
        target="${SAVED[$key]}"
        aerospace move-node-to-workspace --window-id "$wid" "$target" 2>/dev/null || true
    fi
done < <(aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}')
