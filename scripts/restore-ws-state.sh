#!/bin/bash
# Restore workspace state after AeroSpace restart.
# Five phases:
#   1. Parse ~/.aerospace-ws-state (fall back to old format)
#   2. Restore monitor-workspace mapping
#   3. Move windows to saved workspaces
#   4. Cleanup invalid workspaces
#   5. Restore focused workspace

export PATH="/opt/homebrew/bin:$PATH"

STATE_FILE="$HOME/.aerospace-ws-state"
OLD_STATE_FILE="$HOME/.aerospace-window-state"

# Give AeroSpace a moment to discover all windows after startup
sleep 1

# --- Phase 1: Parse state file ---

SAVED_FOCUSED=""
declare -a MON_IDS=()
declare -A MON_WS=()
declare -a WIN_IDS=()
declare -A WIN_WS=()
declare -A WIN_KEY=()  # window-id → "app|title" for fallback matching

if [[ -f "$STATE_FILE" ]]; then
    while IFS= read -r line; do
        [[ "$line" == \#* || -z "$line" ]] && continue
        if [[ "$line" == focused=* ]]; then
            SAVED_FOCUSED="${line#focused=}"
        elif [[ "$line" == monitor\|* ]]; then
            IFS='|' read -r _ mid ws <<< "$line"
            MON_IDS+=("$mid")
            MON_WS["$mid"]="$ws"
        elif [[ "$line" == window\|* ]]; then
            IFS='|' read -r _ wid app title ws <<< "$line"
            WIN_IDS+=("$wid")
            WIN_WS["$wid"]="$ws"
            WIN_KEY["$wid"]="$app|$title"
        fi
    done < "$STATE_FILE"
elif [[ -f "$OLD_STATE_FILE" ]]; then
    # Migration: old format is just "app|title|workspace" per line
    # No monitor mapping or focused workspace available
    while IFS='|' read -r app title ws; do
        [[ -z "$app" ]] && continue
        # Store with synthetic key for app+title matching
        local_key="$app|$title"
        WIN_KEY["old_${#WIN_IDS[@]}"]="$local_key"
        WIN_WS["old_${#WIN_IDS[@]}"]="$ws"
        WIN_IDS+=("old_${#WIN_IDS[@]}")
    done < "$OLD_STATE_FILE"
else
    exit 0
fi

# --- Phase 2: Restore monitor-workspace mapping ---

CURRENT_MONS=($(aerospace list-monitors --format '%{monitor-id}' 2>/dev/null))

# Map saved monitor positions to current monitors positionally
for i in "${!MON_IDS[@]}"; do
    saved_mid="${MON_IDS[$i]}"
    ws="${MON_WS[$saved_mid]}"
    [[ -z "$ws" ]] && continue

    if [[ $i -lt ${#CURRENT_MONS[@]} ]]; then
        target_mon="${CURRENT_MONS[$i]}"
    else
        # More saved monitors than current — overflow to monitor 1
        target_mon="1"
    fi

    aerospace focus-monitor "$target_mon" 2>/dev/null
    sleep 0.05
    aerospace summon-workspace "$ws" 2>/dev/null
    sleep 0.05
done

# --- Phase 3: Move windows to saved workspaces ---

# Build app+title → workspace lookup from saved state for fallback matching
declare -A SAVED_BY_KEY=()
for wid in "${WIN_IDS[@]}"; do
    key="${WIN_KEY[$wid]}"
    ws="${WIN_WS[$wid]}"
    [[ -n "$key" && -n "$ws" ]] && SAVED_BY_KEY["$key"]="$ws"
done

while IFS='|' read -r wid app title; do
    [[ -z "$wid" ]] && continue
    target=""

    # Try window-id match first (works for config-reload, same session)
    if [[ -n "${WIN_WS[$wid]+x}" ]]; then
        target="${WIN_WS[$wid]}"
    else
        # Fall back to app+title match (works across restarts)
        key="$app|$title"
        if [[ -n "${SAVED_BY_KEY[$key]+x}" ]]; then
            target="${SAVED_BY_KEY[$key]}"
        fi
    fi

    if [[ -n "$target" ]]; then
        aerospace move-node-to-workspace --window-id "$wid" "$target" 2>/dev/null || true
    fi
done < <(aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' 2>/dev/null)

# --- Phase 4: Cleanup invalid workspaces ---

~/.local/bin/cleanup-ws.sh 2>/dev/null || true

# --- Phase 5: Restore focused workspace ---

if [[ -n "$SAVED_FOCUSED" ]]; then
    aerospace workspace "$SAVED_FOCUSED" 2>/dev/null || true
fi
