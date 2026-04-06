# dotfiles

macOS configuration files and settings.

## Contents

### Shell
- `shell/` - Zsh/Bash configuration (see [shell/README.md](shell/README.md))
  - `.zshrc` - Zsh config with visual selection, undo/redo, stale config indicator
  - `.p10k.zsh` - Powerlevel10k prompt theme
  - `.bash_profile` - Bash profile
  - `.git-completion.bash` - Git autocompletion

### Editor & Terminal
- `.vimrc` - Vim configuration
- `.tmux.conf` - Tmux configuration
- `com.googlecode.iterm2.plist` - iTerm2 settings
- `iterm_keymap.itermkeymap` - iTerm2 keybindings

### Window Management
- `.aerospace.toml` - [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling window manager
- `aerospace/` - Custom AeroSpace build with two patches:
  - **focus-guard** - Suppresses unwanted app-initiated focus changes (e.g. Chrome reasserting focus) that fire within 250ms of an AeroSpace command
  - **freeze-tiling** - Adds a `freeze-tiling` command to pause automatic retiling without disabling AeroSpace (useful for Dock toggling)
  - Built via `aerospace/build.sh` against a pinned AeroSpace version

### Keyboard
- `karabiner/` - [Karabiner Elements](https://karabiner-elements.pqrs.org/) key remapping (see [karabiner/README.md](karabiner/README.md))
- `keyboard-layouts/` - Custom keyboard layouts (Mongolian QWERTY)

### Automation
- `.hammerspoon/` - [Hammerspoon](https://www.hammerspoon.org/) automation scripts (see [.hammerspoon/README.md](.hammerspoon/README.md))
  - Scroll layer, cursor grid, line navigation hold-to-repeat
  - Workspace grid overlay, focus border flash, workspace notifications
  - Key repeat suppression for Caps Lock layers
- `espanso/` - [Espanso](https://espanso.org/) text expansion snippets

### Scripts
- `scripts/` - Utility scripts (auto-symlinked to `~/.local/bin/` by `install.sh`)
  - `ws.sh` - Workspace operations (focus, move, swap) with command queuing
  - `smart-focus.sh` / `smart-move.sh` - Cross-monitor window focus and movement
  - `apply_t_ws_layer.py` - Generates T layer workspace manipulators in karabiner.json
  - `apply_physical_trackers.py` - Generates physical key tracker manipulators
  - `apply_f_cursor_grid.py` - Generates F layer cursor grid manipulators
  - `save-ws-state.sh` / `restore-ws-state.sh` - Window-to-workspace state preservation across AeroSpace restarts
  - `dock-peek.sh` / `clean-dock.sh` / `dock-toggle` - Dock management utilities
  - `toggle-input-source.sh` - Input source switching

### Browser Extensions
- `vimium_c.json` - [Vimium C](https://github.com/nicolerenee/vimium-c) settings
- `stylus/` - Custom CSS styles for websites
- `chrome-extensions/tab-mover/` - Custom Chrome extension for moving tabs between windows directionally (left/right/up/down across displays) with vim-style reordering

### Raycast
- `raycast/` - [Raycast](https://www.raycast.com/) scripts (Sidecar toggle)

### Git
- `.gitconfig` - Git configuration

## Setup

```bash
./install.sh          # Symlink all configs
./reload.sh --all     # Reload all app configs
```

See `install.sh --help` and `reload.sh --help` for selective installation and reloading.

### Manual steps

These require manual installation and can't be automated by `install.sh`:

- **AeroSpace custom build** — Run `aerospace/build.sh` to compile and install the patched binary
- **Chrome extensions** — Load `chrome-extensions/tab-mover/` as an unpacked extension in `chrome://extensions`
- **Vimium C** — Import settings from `vimium_c.json`
- **Stylus** — Import styles from `stylus/`
- **Keyboard layouts** — Copy from `keyboard-layouts/` to `~/Library/Keyboard Layouts/`
- **Raycast scripts** — Import scripts from `raycast/` in Raycast preferences
