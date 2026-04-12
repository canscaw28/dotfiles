#!/usr/bin/env bash
# Open predefined apps and move their windows to assigned workspaces.
# Skips launching if already running; activates hidden apps so AeroSpace can see them.

set -uo pipefail

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

# Open/activate all apps in parallel
for entry in "${APPS[@]}"; do
    IFS='|' read -r bundle_id _ <<< "$entry"
    open -b "$bundle_id" &
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
