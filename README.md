# dotfiles

macOS configuration files and settings.

## Contents

### Shell
- `.zshrc` - Zsh configuration
- `.bash_profile` - Bash profile
- `.p10k.zsh` - Powerlevel10k theme config
- `.git-completion.bash` - Git autocompletion

#### Zsh Features

**Stale Config Indicator**: When `.zshrc` is modified, a red `⟳ run: source ~/.zshrc` indicator appears in your prompt. This helps you know when to reload your shell config, especially useful across multiple tmux panes.

**Visual Selection Mode**: GUI-like text selection in the terminal:
- Shift+Arrow keys to select text character by character
- Ctrl+Shift+Left/Right to select words
- Shift+Home/End to select to line start/end
- Backspace/Delete removes selected text
- Selection integrates with clipboard via Caps+Cmd+C (copy) and Caps+Cmd+X (cut)

**Undo/Redo** (via Karabiner in iTerm2):
- Cmd+Z to undo text changes
- Cmd+Shift+Z to redo

### Editor & Terminal
- `.vimrc` - Vim configuration
- `.tmux.conf` - Tmux configuration
- `com.googlecode.iterm2.plist` - iTerm2 settings
- `iterm_keymap.itermkeymap` - iTerm2 keybindings

### Window Management
- `.aerospace.toml` - [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling window manager

### Keyboard
- `karabiner/` - [Karabiner Elements](https://karabiner-elements.pqrs.org/) key remapping (see [karabiner/README.md](karabiner/README.md))
- `keyboard-layouts/` - Custom keyboard layouts (Mongolian QWERTY)

### Automation
- `.hammerspoon/` - [Hammerspoon](https://www.hammerspoon.org/) automation scripts

### Browser Extensions
- `vimium_c.json` - [Vimium C](https://github.com/nicolerenee/vimium-c) settings
- `stylus/` - Custom CSS styles for websites

### Git
- `.gitconfig` - Git configuration
