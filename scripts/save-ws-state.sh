#!/bin/zsh
# Save workspace state for persistence across AeroSpace restarts.
# Writes focused workspace, monitor-workspace mapping, and window info
# to ~/.aerospace-ws-state. Tab-delimited. Atomic write via tmp+mv.
#
# Chrome windows are fingerprinted by first 5 tab URLs + tab count
# (queried via AppleScript). This is more stable than window title
# since it doesn't change when the user switches active tabs.

export PATH="/opt/homebrew/bin:$PATH"

STATE_FILE="$HOME/.aerospace-ws-state"
TMP_FILE="${STATE_FILE}.tmp.$$"

focused=$(aerospace list-workspaces --focused 2>/dev/null) || exit 0
monitors=(${(f)"$(aerospace list-monitors --format '%{monitor-id}' 2>/dev/null)"}) || exit 0

# Query Chrome: title (for correlation), first 5 tab URLs, tab count per window
typeset -A CHROME_FINGER  # chrome_title → "url1|url2|url3|url4|url5|count"
while IFS=$'\t' read -r _t _u1 _u2 _u3 _u4 _u5 _n; do
    [[ -z "$_t" ]] && continue
    CHROME_FINGER[$_t]="${_u1}|${_u2}|${_u3}|${_u4}|${_u5}|${_n}"
done < <(osascript -e '
    set sep to ASCII character 9
    if application "Google Chrome" is running then
        tell application "Google Chrome"
            set output to ""
            repeat with w in windows
                set t to title of w
                set n to count of tabs of w
                set u1 to URL of tab 1 of w
                set u2 to ""
                set u3 to ""
                set u4 to ""
                set u5 to ""
                if n > 1 then set u2 to URL of tab 2 of w
                if n > 2 then set u3 to URL of tab 3 of w
                if n > 3 then set u4 to URL of tab 4 of w
                if n > 4 then set u5 to URL of tab 5 of w
                set output to output & t & sep & u1 & sep & u2 & sep & u3 & sep & u4 & sep & u5 & sep & (n as text) & linefeed
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

    # Window-workspace mapping with Chrome fingerprint
    while IFS=$'\t' read -r wid app title ws; do
        [[ -z "$wid" ]] && continue
        finger="-"
        if [[ "$app" == "Google Chrome" ]]; then
            # AeroSpace title: "<page> - High memory usage - X GB - Google Chrome - <Profile>"
            # AppleScript title: "<page>" only. Strip both suffixes to match.
            local chrome_title="${title% - Google Chrome*}"
            chrome_title="${chrome_title% - High memory usage*}"
            finger="${CHROME_FINGER[$chrome_title]:-}"
        fi
        printf 'window\t%s\t%s\t%s\t%s\t%s\n' "$wid" "$app" "$title" "$finger" "$ws"
    done < <(aerospace list-windows --all --format $'%{window-id}\t%{app-name}\t%{window-title}\t%{workspace}' 2>/dev/null)
} > "$TMP_FILE"

mv -f "$TMP_FILE" "$STATE_FILE"
