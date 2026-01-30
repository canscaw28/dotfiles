# Shell Configuration

Zsh and Bash shell configuration files.

## Files

| File | Description |
|------|-------------|
| `.zshrc` | Main Zsh configuration with custom widgets, keybindings, and prompt setup |
| `.bash_profile` | Bash profile for login shells |
| `.p10k.zsh` | [Powerlevel10k](https://github.com/romkatv/powerlevel10k) prompt theme configuration |
| `.git-completion.bash` | Git command autocompletion |

## Zsh Features

### Stale Config Indicator

When `.zshrc` is modified after being sourced, a red indicator appears in your prompt:

```
⟳ run: source ~/.zshrc
```

This helps you know when to reload your shell config, especially useful when working across multiple tmux panes.

### Visual Selection Mode

GUI-like text selection in the terminal, similar to standard text editors:

| Shortcut | Action |
|----------|--------|
| Shift+Left/Right | Select character by character |
| Ctrl+Shift+Left/Right | Select word by word |
| Shift+Home | Select to start of line |
| Shift+End | Select to end of line |
| Backspace/Delete | Delete selected text |
| Caps+Cmd+C | Copy selection to system clipboard |
| Caps+Cmd+X | Cut selection to system clipboard |

### Undo/Redo (iTerm2)

Standard undo/redo for command line editing (requires Karabiner mappings):

| Shortcut | Action |
|----------|--------|
| Cmd+Z | Undo last text change |
| Cmd+Shift+Z | Redo |

### Delete Operations (iTerm2)

Enhanced delete commands via Caps Lock layer (requires Karabiner):

| Shortcut | Action |
|----------|--------|
| Caps+D+H | Delete character left (backspace) |
| Caps+D+L | Delete character right |
| Caps+D+U | Delete word left |
| Caps+D+I | Delete word right |
| Caps+D+Y | Delete to start of line |
| Caps+D+O | Delete to end of line |
| Caps+D+J | Delete to line below |
| Caps+D+K | Delete to line above |

## Powerlevel10k Prompt

The prompt is configured with:
- Current directory (truncated)
- Git status and branch
- Command execution time
- Exit status indicator
- Stale zshrc indicator (custom segment)

## Installation

```bash
./install.sh --shell
```

Or manually:
```bash
ln -s /path/to/dotfiles/shell/.zshrc ~/.zshrc
ln -s /path/to/dotfiles/shell/.p10k.zsh ~/.p10k.zsh
ln -s /path/to/dotfiles/shell/.bash_profile ~/.bash_profile
ln -s /path/to/dotfiles/shell/.git-completion.bash ~/.git-completion.bash
```
