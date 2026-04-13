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

# Prevent concurrent runs
LOCK="/tmp/workspace-setup.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

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

# Save focused window — moving the focused window off the current workspace
# causes AeroSpace to follow focus to the target; restoring by window ID is
# more reliable than by workspace (which can redirect to another monitor).
ORIGINAL_WIN=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)

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

# Restore focus to original window
if [[ -n "${ORIGINAL_WIN:-}" ]]; then
    aerospace focus --window-id "$ORIGINAL_WIN" 2>/dev/null || true
fi
