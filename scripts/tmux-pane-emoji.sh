#!/bin/bash
# Tag a pane with an emoji that fits its title and that no other pane is using,
# shown in its border label. Run (in the background) by the pane-title-changed
# hook in .tmux.conf whenever the title's text changes.
pane="$1"

title=$(tmux display -p -t "$pane" '#{s/^[^A-Za-z0-9 ]* //:pane_title}')
[ -z "$title" ] && exit 0

used() { tmux list-panes -a -F '#{pane_id} #{@emoji}' | awk -v p="$pane" '$1 != p && $2 != "" { printf "%s ", $2 }'; }
used=$(used)

# Off the cwd so the call doesn't pick up a project's CLAUDE.md or settings.
emoji=$(cd /tmp && claude -p --model haiku --tools "" --strict-mcp-config \
    --setting-sources "" --no-session-persistence \
    "Pick one emoji that clearly relates to this topic, so it can label a terminal pane: \"$title\". ${used:+Do not use any of these: $used. }Output only the emoji, nothing else." 2>/dev/null |
    tr -d '[:space:]')

# A model failure, or another pane taking the same emoji while this one waited,
# falls back to the first free emoji from a pool.
used=$(used)
if [ -z "$emoji" ] || [ ${#emoji} -gt 8 ] || [[ " $used" == *" $emoji "* ]]; then
    emoji=""
    for e in 🦊 🐙 🦉 🐢 🦋 🐝 🦀 🐳 🦄 🐸 🐧 🦁 🐼 🦜 🐞 🦈 🌵 🍄 🌻 🍋; do
        [[ " $used" == *" $e "* ]] || { emoji=$e; break; }
    done
fi

# The title may have moved on while the model was thinking; only the latest
# run should win.
[ "$(tmux display -p -t "$pane" '#{s/^[^A-Za-z0-9 ]* //:pane_title}')" = "$title" ] || exit 0
tmux set -p -t "$pane" @emoji "$emoji"
