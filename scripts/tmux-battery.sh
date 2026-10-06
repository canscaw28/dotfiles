#!/bin/bash
# tmux status bar: battery level, with a bolt while on power. Prints nothing on
# a machine without a battery. Icons are Nerd Font glyphs as UTF-8 octal.
out=$(pmset -g batt)
pct=$(grep -Eo '[0-9]+%' <<<"$out" | head -1 | tr -d %)
[[ -n $pct ]] || exit 0
if   (( pct >= 90 )); then icon='\357\211\200'
elif (( pct >= 60 )); then icon='\357\211\201'
elif (( pct >= 35 )); then icon='\357\211\202'
elif (( pct >= 10 )); then icon='\357\211\203'
else icon='\357\211\204'
fi
[[ $out == *"AC Power"* ]] && icon="\357\203\247 $icon"
printf "$icon %s%%" "$pct"
