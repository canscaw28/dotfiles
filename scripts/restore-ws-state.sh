#!/bin/zsh
# Restore workspace state after AeroSpace restart.
# Five phases:
#   1. Parse ~/.aerospace-ws-state (fall back to old format)
#   2. Restore monitor-workspace mapping
#   3. Move windows to saved workspaces (window-id → fingerprint → app+title)
#   4. Cleanup invalid workspaces
#   5. Restore focused workspace

export PATH="/opt/homebrew/bin:$PATH"

STATE_FILE="$HOME/.aerospace-ws-state"
OLD_STATE_FILE="$HOME/.aerospace-window-state"

# Give AeroSpace a moment to discover all windows after startup
sleep 1

# --- Phase 1: Parse state file ---

SAVED_FOCUSED=""
typeset -a MON_IDS=()
typeset -A MON_WS=()
typeset -A WIN_WS=()         # wid → ws (for window-id matching)
typeset -A BY_FINGER=()      # "app\ttitle\ttc\tat" → "ws1 ws2 ..."
typeset -A BY_APPTITLE=()    # "app\ttitle" → "ws1 ws2 ..."

if [[ -f "$STATE_FILE" ]]; then
    while IFS= read -r line; do
        [[ "$line" == \#* || -z "$line" ]] && continue
        if [[ "$line" == focused=* ]]; then
            SAVED_FOCUSED="${line#focused=}"
        elif [[ "$line" == monitor$'\t'* ]]; then
            IFS=$'\t' read -r _ mid ws <<< "$line"
            MON_IDS+=("$mid")
            MON_WS[$mid]="$ws"
        elif [[ "$line" == window$'\t'* ]]; then
            IFS=$'\t' read -r _ wid app title tc at ws <<< "$line"
            WIN_WS[$wid]="$ws"
            # Fingerprint map (with Chrome tab info when available)
            if [[ -n "$tc" ]]; then
                local fkey="${app}"$'\t'"${title}"$'\t'"${tc}"$'\t'"${at}"
                BY_FINGER[$fkey]="${BY_FINGER[$fkey]:+${BY_FINGER[$fkey]} }${ws}"
            fi
            # App+title map (fallback for all windows)
            local atkey="${app}"$'\t'"${title}"
            BY_APPTITLE[$atkey]="${BY_APPTITLE[$atkey]:+${BY_APPTITLE[$atkey]} }${ws}"
        fi
    done < "$STATE_FILE"
elif [[ -f "$OLD_STATE_FILE" ]]; then
    # Migration: old format is "app|title|workspace" per line
    while IFS='|' read -r app title ws; do
        [[ -z "$app" ]] && continue
        local atkey="${app}"$'\t'"${title}"
        BY_APPTITLE[$atkey]="${BY_APPTITLE[$atkey]:+${BY_APPTITLE[$atkey]} }${ws}"
    done < "$OLD_STATE_FILE"
else
    exit 0
fi

# --- Phase 2: Restore monitor-workspace mapping ---

CURRENT_MONS=(${(f)"$(aerospace list-monitors --format '%{monitor-id}' 2>/dev/null)"})

for (( i=1; i<=${#MON_IDS}; i++ )); do
    local saved_mid="${MON_IDS[$i]}"
    local ws="${MON_WS[$saved_mid]}"
    [[ -z "$ws" ]] && continue

    local target_mon
    if (( i <= ${#CURRENT_MONS} )); then
        target_mon="${CURRENT_MONS[$i]}"
    else
        target_mon="1"
    fi

    aerospace focus-monitor "$target_mon" 2>/dev/null
    sleep 0.05
    aerospace summon-workspace "$ws" 2>/dev/null
    sleep 0.05
done

# --- Phase 3: Move windows to saved workspaces ---

# Query current Chrome tab info for fingerprint matching
typeset -A CUR_TC CUR_AT
while IFS=$'\t' read -r _t _tc _at; do
    [[ -z "$_t" ]] && continue
    CUR_TC[$_t]=$_tc
    CUR_AT[$_t]=$_at
done < <(osascript -e '
    set sep to ASCII character 9
    if application "Google Chrome" is running then
        tell application "Google Chrome"
            set output to ""
            repeat with w in windows
                set t to title of w
                set n to (count of tabs of w) as text
                set a to (active tab index of w) as text
                set output to output & t & sep & n & sep & a & linefeed
            end repeat
            return output
        end tell
    end if
' 2>/dev/null)

# Collect current windows for multi-pass matching
typeset -a CUR_WIDS=() CUR_APPS=() CUR_TITLES=()
while IFS=$'\t' read -r wid app title; do
    [[ -z "$wid" ]] && continue
    CUR_WIDS+=("$wid")
    CUR_APPS+=("$app")
    CUR_TITLES+=("$title")
done < <(aerospace list-windows --all --format $'%{window-id}\t%{app-name}\t%{window-title}' 2>/dev/null)

typeset -A ASSIGNED=()  # wid → target workspace

# Pass 1: Window-ID match (works for config-reload, same session)
for (( i=1; i<=${#CUR_WIDS}; i++ )); do
    local wid="${CUR_WIDS[$i]}"
    if [[ -n "${WIN_WS[$wid]+x}" ]]; then
        ASSIGNED[$wid]="${WIN_WS[$wid]}"
    fi
done

# Pass 2: Full fingerprint match (app + title + Chrome tab info)
for (( i=1; i<=${#CUR_WIDS}; i++ )); do
    local wid="${CUR_WIDS[$i]}" app="${CUR_APPS[$i]}" title="${CUR_TITLES[$i]}"
    [[ -n "${ASSIGNED[$wid]+x}" ]] && continue

    local tc="" at=""
    if [[ "$app" == "Google Chrome" ]]; then
        # AeroSpace title: "<page> - High memory usage - X GB - Google Chrome - <Profile>"
        # AppleScript title: "<page>" only. Strip both suffixes to match.
        local chrome_title="${title% - Google Chrome*}"
        chrome_title="${chrome_title% - High memory usage*}"
        tc="${CUR_TC[$chrome_title]:-}"
        at="${CUR_AT[$chrome_title]:-}"
    fi
    [[ -z "$tc" ]] && continue  # no Chrome info, skip to pass 3

    local fkey="${app}"$'\t'"${title}"$'\t'"${tc}"$'\t'"${at}"
    local flist="${BY_FINGER[$fkey]}"
    [[ -z "$flist" ]] && continue

    # Consume first workspace from list
    ASSIGNED[$wid]="${flist%% *}"
    local rest="${flist#* }"
    if [[ "$rest" == "$flist" ]]; then
        unset "BY_FINGER[$fkey]"
    else
        BY_FINGER[$fkey]="$rest"
    fi

    # Also consume from app+title map to prevent double-assignment
    local atkey="${app}"$'\t'"${title}"
    local atlist="${BY_APPTITLE[$atkey]}"
    if [[ -n "$atlist" ]]; then
        local at_rest="${atlist#* }"
        if [[ "$at_rest" == "$atlist" ]]; then
            unset "BY_APPTITLE[$atkey]"
        else
            BY_APPTITLE[$atkey]="$at_rest"
        fi
    fi
done

# Pass 3: App+title match (fallback — handles title drift, non-Chrome apps)
for (( i=1; i<=${#CUR_WIDS}; i++ )); do
    local wid="${CUR_WIDS[$i]}" app="${CUR_APPS[$i]}" title="${CUR_TITLES[$i]}"
    [[ -n "${ASSIGNED[$wid]+x}" ]] && continue

    local atkey="${app}"$'\t'"${title}"
    local atlist="${BY_APPTITLE[$atkey]}"
    [[ -z "$atlist" ]] && continue

    # Consume first workspace from list
    ASSIGNED[$wid]="${atlist%% *}"
    local rest="${atlist#* }"
    if [[ "$rest" == "$atlist" ]]; then
        unset "BY_APPTITLE[$atkey]"
    else
        BY_APPTITLE[$atkey]="$rest"
    fi
done

# Execute all moves
for wid in ${(k)ASSIGNED}; do
    aerospace move-node-to-workspace --window-id "$wid" "${ASSIGNED[$wid]}" 2>/dev/null || true
done

# --- Phase 4: Cleanup invalid workspaces ---

~/.local/bin/cleanup-ws.sh 2>/dev/null || true

# --- Phase 5: Restore focused workspace ---

if [[ -n "$SAVED_FOCUSED" ]]; then
    aerospace workspace "$SAVED_FOCUSED" 2>/dev/null || true
fi
