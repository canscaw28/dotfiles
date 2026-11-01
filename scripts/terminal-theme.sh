#!/bin/bash
# Steps iTerm and tmux through contrast levels: muted (the iTerm profile's own
# palette, ~7:1 text on background), medium (~10:1) and bright (~12.5:1, with
# brighter accents too), for dimmer displays where the muted grey text reads
# as dull. iTerm's colors change per session through its SetColors escape,
# written straight to every tmux client's tty so all open windows switch at
# once. The level lives in a state file; tmux re-applies it whenever a client
# attaches.
#   terminal-theme.sh up | down | muted | medium | bright | apply
set -eo pipefail

tmux=/opt/homebrew/bin/tmux
state="$HOME/.local/state/terminal-theme"

# fg and br_black double as tmux's @fg and @muted. The background stays the
# same in all of them, so only text and accents get brighter.
muted=(
    fg=a6afb8 bold=a6afb8 selfg=a6afb8
    black=18262f red=ef5253 green=7cc844 yellow=e4b51c
    blue=33b5e1 magenta=a363d5 cyan=52cbb0 white=a6afb8
    br_black=667581 br_red=ef5253 br_green=7cc844 br_yellow=e4b51c
    br_blue=33b5e1 br_magenta=a363d5 br_cyan=52cbb0 br_white=f5f7fa
)
medium=(
    fg=c8d0d8 bold=c8d0d8 selfg=c8d0d8
    black=18262f red=ef5253 green=7cc844 yellow=e4b51c
    blue=33b5e1 magenta=a363d5 cyan=52cbb0 white=c8d0d8
    br_black=7a8894 br_red=ef5253 br_green=7cc844 br_yellow=e4b51c
    br_blue=33b5e1 br_magenta=a363d5 br_cyan=52cbb0 br_white=f5f7fa
)
bright=(
    fg=e3e8ed bold=f5f7fa selfg=f5f7fa
    black=18262f red=ff6b6c green=95dd5c yellow=f5c93a
    blue=5cc8f0 magenta=bd84ea cyan=6fe0c6 white=d5dce2
    br_black=8c9aa6 br_red=ff6b6c br_green=95dd5c br_yellow=f5c93a
    br_blue=5cc8f0 br_magenta=bd84ea br_cyan=6fe0c6 br_white=ffffff
)

levels=(muted medium bright)
current=$(cat "$state" 2>/dev/null || echo muted)
i=0
for n in "${!levels[@]}"; do [ "${levels[$n]}" = "$current" ] && i=$n; done
case "$1" in
    up)   (( i < ${#levels[@]} - 1 )) && i=$(( i + 1 )) ;;
    down) (( i > 0 )) && i=$(( i - 1 )) ;;
    muted|medium|bright)
        for n in "${!levels[@]}"; do [ "${levels[$n]}" = "$1" ] && i=$n; done ;;
    apply) ;;
    *) echo "usage: $(basename "$0") up|down|muted|medium|bright|apply" >&2; exit 1 ;;
esac
theme=${levels[$i]}
mkdir -p "$(dirname "$state")"
echo "$theme" > "$state"

case "$theme" in
    muted)  palette=("${muted[@]}") ;;
    medium) palette=("${medium[@]}") ;;
    bright) palette=("${bright[@]}") ;;
esac

# One write per tty, so tmux's own output can't land inside an escape.
seq=""
for kv in "${palette[@]}"; do
    seq+=$'\e]1337;SetColors='"${kv%%=*}=srgb:${kv#*=}"$'\a'
    case "${kv%%=*}" in
        fg) $tmux set -g @fg "#${kv#*=}" ;;
        br_black) $tmux set -g @muted "#${kv#*=}" ;;
    esac
done
$tmux list-clients -F '#{client_tty}' | while read -r tty; do
    printf '%s' "$seq" > "$tty"
done

[ "$1" = apply ] || $tmux display-message "Theme: $theme"
