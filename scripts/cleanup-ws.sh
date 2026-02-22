#!/bin/bash
# Remove invalid workspaces from AeroSpace.
# Valid workspaces: 6 7 8 9 0 y u i o p h j k l ; n m comma . / ~
# Invalid workspaces (e.g. numbered defaults) have their windows moved to 0,
# then get replaced on their monitor by a valid workspace from saved state.
# AeroSpace garbage-collects empty hidden workspaces automatically.

export PATH="/opt/homebrew/bin:$PATH"

VALID_WS="6 7 8 9 0 y u i o p h j k l ; n m comma . / ~"
STATE_FILE="$HOME/.aerospace-ws-state"

is_valid() {
    local ws="$1"
    for v in $VALID_WS; do
        [[ "$v" == "$ws" ]] && return 0
    done
    return 1
}

all_ws=$(aerospace list-workspaces --all 2>/dev/null) || exit 0

invalid=()
for ws in $all_ws; do
    is_valid "$ws" || invalid+=("$ws")
done

[[ ${#invalid[@]} -eq 0 ]] && exit 0

# Load saved monitor mapping for replacement workspaces
declare -A SAVED_MON
if [[ -f "$STATE_FILE" ]]; then
    while IFS='|' read -r type mid ws; do
        [[ "$type" == "monitor" ]] && SAVED_MON["$mid"]="$ws"
    done < "$STATE_FILE"
fi

for ws in "${invalid[@]}"; do
    # Move all windows from invalid workspace to h
    wids=$(aerospace list-windows --workspace "$ws" --format '%{window-id}' 2>/dev/null)
    for wid in $wids; do
        aerospace move-node-to-workspace --window-id "$wid" 0 2>/dev/null || true
    done

    # If visible on a monitor, replace it with a valid workspace
    monitors=$(aerospace list-monitors --format '%{monitor-id}' 2>/dev/null)
    for mid in $monitors; do
        visible=$(aerospace list-workspaces --monitor "$mid" --visible 2>/dev/null)
        if [[ "$visible" == "$ws" ]]; then
            # Use saved workspace for this monitor, or fall back to 0
            replacement="${SAVED_MON[$mid]:-0}"
            aerospace focus-monitor "$mid" 2>/dev/null
            aerospace summon-workspace "$replacement" 2>/dev/null
            break
        fi
    done
done
