#!/usr/bin/env bash
# Open predefined apps and move their windows to assigned workspaces.
# Skips launching if already running; activates hidden apps so AeroSpace can see them.

set -uo pipefail

# Karabiner shell_command runs with minimal PATH; ensure homebrew is available
export PATH="/opt/homebrew/bin:/Users/craig/.local/bin:$PATH"

# Detach from Karabiner's process tree on first invocation.
# Karabiner SIGKILL's shell_command processes unpredictably; re-exec into a new
# session so the original process exits immediately and the real work runs independently.
if [[ -z "${_WS_SETUP_DETACHED:-}" ]]; then
    export _WS_SETUP_DETACHED=1
    "$0" "$@" &>/dev/null &
    exit 0
fi

# Prevent concurrent runs (PID-based lock with stale detection)
LOCK="/tmp/workspace-setup.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    # Check if holder is still alive
    if [[ -f "$LOCK/pid" ]] && ! kill -0 "$(cat "$LOCK/pid")" 2>/dev/null; then
        rm -rf "$LOCK"
        mkdir "$LOCK" 2>/dev/null || exit 0
    else
        exit 0
    fi
fi
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT

# App definitions: "BundleID|TargetWorkspace"
APPS=(
    "com.googlecode.iterm2|k"
    "com.apple.MobileSMS|n"
    "io.rize|n"
    "com.tinyspeck.slackmacgap|m"
)

# Open apps that don't already have windows (skip already-running apps)
for entry in "${APPS[@]}"; do
    IFS='|' read -r bundle_id _ <<< "$entry"
    count=$(aerospace list-windows --monitor all --app-bundle-id "$bundle_id" --count 2>/dev/null || echo 0)
    if [[ "$count" == "0" ]]; then
        open -gb "$bundle_id" &
    fi
done
wait

# Wait until all apps have at least one AeroSpace window (up to 10s total)
MAX_WAIT=20
elapsed=0
while (( elapsed < MAX_WAIT )); do
    all_ready=true
    for entry in "${APPS[@]}"; do
        IFS='|' read -r bundle_id _ <<< "$entry"
        count=$(aerospace list-windows --monitor all --app-bundle-id "$bundle_id" --count 2>/dev/null || echo 0)
        if [[ "$count" == "0" ]]; then
            all_ready=false
            break
        fi
    done
    $all_ready && break
    sleep 0.5
    (( elapsed++ )) || true
done

# Save focused workspace — restore by workspace rather than window ID since
# the focused window might be one of the apps being moved.
ORIGINAL_WS=$(aerospace list-workspaces --focused 2>/dev/null)
ORIGINAL_MON=$(aerospace list-monitors --focused --format '%{monitor-id}' 2>/dev/null)

# Move windows to correct workspaces
for entry in "${APPS[@]}"; do
    IFS='|' read -r bundle_id target_ws <<< "$entry"
    while IFS=$'\t' read -r wid ws; do
        [[ -z "$wid" ]] && continue
        if [[ "$ws" != "$target_ws" ]]; then
            aerospace move-node-to-workspace --window-id "$wid" "$target_ws" 2>/dev/null || true
        fi
    done < <(aerospace list-windows --monitor all --format $'%{window-id}\t%{workspace}' --app-bundle-id "$bundle_id" 2>/dev/null)
done

# Restore focus — use focus-monitor + workspace to ensure we land back on the
# original monitor even if the workspace moved.
if [[ -n "${ORIGINAL_MON:-}" ]]; then
    aerospace focus-monitor "$ORIGINAL_MON" 2>/dev/null || true
fi
if [[ -n "${ORIGINAL_WS:-}" ]]; then
    aerospace workspace "$ORIGINAL_WS" 2>/dev/null || true
fi
