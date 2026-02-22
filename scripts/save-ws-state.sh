#!/bin/bash
# Save workspace state for persistence across AeroSpace restarts.
# Writes focused workspace, monitor-workspace mapping, and window info
# to ~/.aerospace-ws-state. Atomic write via tmp+mv.

export PATH="/opt/homebrew/bin:$PATH"

STATE_FILE="$HOME/.aerospace-ws-state"
TMP_FILE="${STATE_FILE}.tmp.$$"

focused=$(aerospace list-workspaces --focused 2>/dev/null) || exit 0
monitors=$(aerospace list-monitors --format '%{monitor-id}' 2>/dev/null) || exit 0

{
    printf '# %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'focused=%s\n' "$focused"

    # Monitor-workspace mapping in monitor-id order (skip ~ buffer)
    for mid in $monitors; do
        ws=$(aerospace list-workspaces --monitor "$mid" --visible 2>/dev/null)
        [[ -z "$ws" || "$ws" == "~" ]] && continue
        printf 'monitor|%s|%s\n' "$mid" "$ws"
    done

    # Window-workspace mapping
    aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' 2>/dev/null | while IFS='|' read -r wid app title ws; do
        [[ -z "$wid" ]] && continue
        printf 'window|%s|%s|%s|%s\n' "$wid" "$app" "$title" "$ws"
    done
} > "$TMP_FILE"

mv -f "$TMP_FILE" "$STATE_FILE"
