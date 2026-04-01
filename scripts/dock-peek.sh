#!/bin/bash
# Show/hide dock overlay by pausing AeroSpace + toggling autohide
# Usage: dock-peek.sh show | hide

DIR="$(dirname "$0")"

case "$1" in
    show)
        /opt/homebrew/bin/aerospace enable off 2>/dev/null
        "$DIR/dock-toggle" show
        ;;
    hide)
        "$DIR/dock-toggle" hide
        # Small delay for dock to start hiding before aerospace re-tiles
        sleep 0.3
        /opt/homebrew/bin/aerospace enable on 2>/dev/null
        ;;
esac
