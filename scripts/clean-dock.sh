#!/usr/bin/env bash
# Quit non-pinned apps visible in the Dock and clear recent apps.
# Skips Finder and background-only processes.

# Get pinned bundle IDs from Dock plist
pinned=$(/usr/bin/defaults read com.apple.dock persistent-apps | grep "bundle-identifier" | sed 's/.*= "\(.*\)";/\1/')

# Get non-background running app bundle IDs
running=$(/usr/bin/osascript -e 'tell application "System Events" to get bundle identifier of every process whose background only is false')

# Convert pinned to newline-separated for matching
IFS=',' read -ra running_arr <<< "$running"

for bid in "${running_arr[@]}"; do
    bid=$(echo "$bid" | xargs)  # trim whitespace
    [ -z "$bid" ] && continue
    # Skip Finder
    [ "$bid" = "com.apple.finder" ] && continue
    # Skip if pinned
    if echo "$pinned" | grep -qx "$bid"; then
        continue
    fi
    # Quit the app
    /usr/bin/osascript -e "tell application id \"$bid\" to quit" &
done
wait

# Clear recent apps
/usr/bin/defaults write com.apple.dock recent-apps -array
sleep 0.5
/usr/bin/killall Dock
