#!/bin/bash
# tmux status bar: where a pane is. Inside git, the repo and branch, named after
# the main checkout so a worktree reads as its repo; elsewhere, a short path.
# Icons are Nerd Font glyphs as UTF-8 octal, since macOS bash 3.2 has no \u.
dir="${1:-$PWD}"
cd "$dir" 2>/dev/null || exit 0
if common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    repo=$(basename "$(dirname "$common")")
    branch=$(git branch --show-current 2>/dev/null)
    [[ -n $branch ]] || branch=$(git rev-parse --short HEAD 2>/dev/null)
    printf '%s \356\202\240 %s' "$repo" "$branch"
else
    printf '\357\201\273 %s' "${dir/#$HOME/~}"
fi
