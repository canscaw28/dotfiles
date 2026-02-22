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

# Find which monitor a workspace is visible on (empty if hidden)
visible_on_monitor() {
    local ws="$1"
    local monitors
    monitors=$(aerospace list-monitors --format '%{monitor-id}' 2>/dev/null)
    for mon in $monitors; do
        if [[ "$(aerospace list-workspaces --monitor "$mon" --visible 2>/dev/null)" == "$ws" ]]; then
            echo "$mon"
            return
        fi
    done
}

# Summon a workspace to a monitor, using ~ buffer yank if it's visible elsewhere
summon_to_monitor() {
    local target_mon="$1" ws="$2"
    local ws_mon
    ws_mon=$(visible_on_monitor "$ws")

    if [[ -z "$ws_mon" ]]; then
        # Hidden — simple summon
        aerospace focus-monitor "$target_mon" 2>/dev/null; sleep 0.05
        aerospace summon-workspace "$ws" 2>/dev/null
        return
    fi

    if [[ "$ws_mon" == "$target_mon" ]]; then
        # Already there
        return
    fi

    # Visible on another monitor — yank via ~ buffer
    # ~ always creates on mon1; move it to ws_mon to hide the workspace there
    aerospace workspace '~' 2>/dev/null; sleep 0.05
    if [[ "$ws_mon" != "1" ]]; then
        aerospace move-workspace-to-monitor "$ws_mon" 2>/dev/null; sleep 0.05
    fi
    aerospace focus-monitor "$target_mon" 2>/dev/null; sleep 0.05
    aerospace summon-workspace "$ws" 2>/dev/null
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
    # Move all windows from invalid workspace to 0
    wids=$(aerospace list-windows --workspace "$ws" --format '%{window-id}' 2>/dev/null)
    for wid in $wids; do
        aerospace move-node-to-workspace --window-id "$wid" 0 2>/dev/null || true
    done

    # If visible on a monitor, replace it with a valid workspace
    inv_mon=$(visible_on_monitor "$ws")
    if [[ -n "$inv_mon" ]]; then
        replacement="${SAVED_MON[$inv_mon]:-0}"
        summon_to_monitor "$inv_mon" "$replacement"
    fi
done
