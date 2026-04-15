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
| Espanso (`espanso/`) | `./reload.sh --espanso` |
| Shell (`.zshrc`, `.bash_profile`) | `./reload.sh --shell` (prints reminder; user must run `source ~/.zshrc`) |

Or reload all configs at once: `./reload.sh --all`

## Keybinding Documentation Policy

Whenever you add, change, or delete a keybinding in any layer YAML file (`karabiner/src/layers/*.yaml`), you MUST update `karabiner/README.md` to reflect the change. Keep the existing table format and section structure — add new rows, update existing rows, or remove rows as needed.

## Worktree Awareness

Config symlinks (e.g. `~/.aerospace.toml`) point to the main repo, not worktrees. When in a worktree, pull changes into the main repo before reloading configs.
