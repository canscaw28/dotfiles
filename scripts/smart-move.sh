#!/bin/bash
direction="$1"
root_layout=$(aerospace list-windows --focused --format '%{workspace-root-container-layout}')

if aerospace move --boundaries-action fail "$direction" 2>/dev/null; then
    sleep 0.01 && aerospace move-mouse window-force-center
    exit 0
fi

is_cross_axis=false
case "$root_layout" in
    h_tiles|h_accordion)
        [[ "$direction" == "up" || "$direction" == "down" ]] && is_cross_axis=true
        ;;
    v_tiles|v_accordion)
        [[ "$direction" == "left" || "$direction" == "right" ]] && is_cross_axis=true
        ;;
esac

if $is_cross_axis; then
    aerospace move "$direction"
    sleep 0.01 && aerospace move-mouse window-force-center
fi
