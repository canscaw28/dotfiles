#!/bin/zsh
# Save workspace state for persistence across AeroSpace restarts.
# Writes focused workspace, monitor-workspace mapping, and window info
# to ~/.aerospace-ws-state. Tab-delimited. Atomic write via tmp+mv.

export PATH="/opt/homebrew/bin:$PATH"

STATE_FILE="$HOME/.aerospace-ws-state"
TMP_FILE="${STATE_FILE}.tmp.$$"

focused=$(aerospace list-workspaces --focused 2>/dev/null) || exit 0
monitors=(${(f)"$(aerospace list-monitors --format '%{monitor-id}' 2>/dev/null)"}) || exit 0

# Query Chrome tab info for window fingerprinting (tab count + active tab index)
typeset -A CHROME_TC CHROME_AT
while IFS=$'\t' read -r _t _tc _at; do
    [[ -z "$_t" ]] && continue
    CHROME_TC[$_t]=$_tc
    CHROME_AT[$_t]=$_at
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

{
    printf '# %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'focused=%s\n' "$focused"

    # Monitor-workspace mapping in monitor-id order (skip ~ buffer)
    for mid in $monitors; do
        ws=$(aerospace list-workspaces --monitor "$mid" --visible 2>/dev/null)
        [[ -z "$ws" || "$ws" == "~" ]] && continue
        printf 'monitor\t%s\t%s\n' "$mid" "$ws"
    done

    # Window-workspace mapping with Chrome enrichment
    while IFS=$'\t' read -r wid app title ws; do
        [[ -z "$wid" ]] && continue
        tc="" at=""
        if [[ "$app" == "Google Chrome" ]]; then
            # AeroSpace title: "<page> - High memory usage - X GB - Google Chrome - <Profile>"
            # AppleScript title: "<page>" only. Strip both suffixes to match.
            local chrome_title="${title% - Google Chrome*}"
            chrome_title="${chrome_title% - High memory usage*}"
            tc="${CHROME_TC[$chrome_title]:-}"
            at="${CHROME_AT[$chrome_title]:-}"
        fi
        printf 'window\t%s\t%s\t%s\t%s\t%s\t%s\n' "$wid" "$app" "$title" "$tc" "$at" "$ws"
    done < <(aerospace list-windows --all --format $'%{window-id}\t%{app-name}\t%{window-title}\t%{workspace}' 2>/dev/null)
} > "$TMP_FILE"

mv -f "$TMP_FILE" "$STATE_FILE"
