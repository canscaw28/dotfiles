#!/bin/bash
# Prevent Chrome's makeKeyAndOrderFront from switching AeroSpace workspaces.
# Repeatedly re-asserts focus on the intended window, which causes AeroSpace's
# runLightSession to cancel any pending refresh triggered by Chrome's side effect.
# Called as a background process by ws.sh, smart-focus.sh, switch-monitor.sh.
#
# Usage: focus-guard.sh <window-id>

export PATH="/opt/homebrew/bin:$PATH"

WID="$1"
[[ -z "$WID" ]] && exit 0

# Kill any previous guard
GUARD_PID_FILE="/tmp/aerospace-focus-guard.pid"
if [[ -f "$GUARD_PID_FILE" ]]; then
    kill "$(cat "$GUARD_PID_FILE")" 2>/dev/null
    rm -f "$GUARD_PID_FILE"
fi

echo $$ > "$GUARD_PID_FILE"
trap 'rm -f "$GUARD_PID_FILE"' EXIT

# Re-assert focus every 30ms for ~200ms (7 iterations)
for _ in 1 2 3 4 5 6 7; do
    sleep 0.03
    aerospace focus --window-id "$WID" 2>/dev/null
done
