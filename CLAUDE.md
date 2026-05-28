# Claude Code Instructions

Global instructions live in `claude/CLAUDE.md` (symlinked to `~/.claude/CLAUDE.md`). This file adds project-specific rules on top.

## Config Reload Policy

After editing any config files, ALWAYS reload them so changes take effect immediately:

| Config | Reload Command |
|--------|----------------|
| Karabiner (`karabiner/src/layers/*.yaml`) | `./reload.sh --karabiner` (builds from YAML sources then reloads) |
| AeroSpace (`.aerospace.toml`) | `./reload.sh --aerospace` |
| Hammerspoon (`.hammerspoon/`) | `./reload.sh --hammerspoon` |
| iTerm2 (`com.googlecode.iterm2.plist`) | `./reload.sh --iterm` |
| Text Expander (`text-expander/*.yml`) | `./reload.sh --text-expander` (syncs personal triggers to macOS TR; HS picks up YAML changes automatically) |
| Shell (`.zshrc`, `.bash_profile`) | `./reload.sh --shell` (prints reminder; user must run `source ~/.zshrc`) |

Or reload all configs at once: `./reload.sh --all`

## Keybinding Documentation Policy

A keybinding change touches **two** places, both required:

1. **The binding** — the relevant `karabiner/src/layers/*.yaml` file.
2. **`karabiner/README.md`** — add/update/remove the row. Keep the existing table format and `##`/`###` section structure intact.

There is **no third place to update.** The on-screen help overlay (`⇪ + ?`) is generated from the README by `karabiner/build_help.py` (→ `.hammerspoon/help_data.json`), so updating the README keeps the overlay in sync automatically. The per-binding row format (`| combo | behavior | description |`) under each layer section is load-bearing — `build_help.py` parses it. `build.py --check` fails if `help_data.json` is stale, so always run `./reload.sh --karabiner` (or `build.py`) after editing the README to regenerate it.

## Worktree Awareness

Config symlinks (e.g. `~/.aerospace.toml`) point to the main repo, not worktrees. When in a worktree, pull changes into the main repo before reloading configs.
