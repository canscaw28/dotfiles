#!/bin/bash

# Dotfiles installation script
# Copies configuration files to their proper locations

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warn "Backing up existing $target to $backup"
        mv "$target" "$backup"
    elif [[ -L "$target" ]]; then
        log_info "Removing existing symlink $target"
        rm "$target"
    fi
}

create_symlink() {
    local source="$1"
    local target="$2"

    if [[ ! -e "$source" ]]; then
        log_error "Source does not exist: $source"
        return 1
    fi

    backup_if_exists "$target"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$target")"

    ln -s "$source" "$target"
    log_info "Linked $target -> $source"
}

install_brew() {
    if command -v brew &>/dev/null; then
        log_info "Homebrew already installed"
    else
        log_info "Installing Homebrew..."
        /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    # Ensure brew is on PATH for the remainder of this script (a fresh
    # install on Apple Silicon won't have /opt/homebrew/bin in PATH yet).
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    log_info "Installing brew packages from Brewfile..."
    brew bundle --file="$DOTFILES_DIR/Brewfile"
}

install_oh_my_zsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log_info "oh-my-zsh already installed"
        return
    fi
    log_info "Installing oh-my-zsh..."
    # KEEP_ZSHRC=yes prevents the installer from clobbering our symlinked
    # .zshrc; RUNZSH=no stops it from dropping into a new zsh shell.
    RUNZSH=no KEEP_ZSHRC=yes sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended
}

install_shell() {
    log_info "Installing shell configs..."
    create_symlink "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
    create_symlink "$DOTFILES_DIR/shell/.bash_profile" "$HOME/.bash_profile"
    create_symlink "$DOTFILES_DIR/shell/.p10k.zsh" "$HOME/.p10k.zsh"
    create_symlink "$DOTFILES_DIR/shell/.git-completion.bash" "$HOME/.git-completion.bash"
}

install_git() {
    log_info "Installing git configs..."
    create_symlink "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
}

install_claude() {
    log_info "Installing global Claude Code config..."
    create_symlink "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
}

install_editor() {
    log_info "Installing editor/terminal configs..."
    create_symlink "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
    create_symlink "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
}

install_scripts() {
    log_info "Installing scripts..."
    for script in "$DOTFILES_DIR"/scripts/*.sh; do
        [[ -e "$script" ]] || continue
        create_symlink "$script" "$HOME/.local/bin/$(basename "$script")"
    done
    # Compiled binaries
    for bin in dock-toggle; do
        [[ -f "$DOTFILES_DIR/scripts/$bin" ]] && \
            create_symlink "$DOTFILES_DIR/scripts/$bin" "$HOME/.local/bin/$bin"
    done
}

install_aerospace() {
    log_info "Installing AeroSpace config..."
    install_scripts
    create_symlink "$DOTFILES_DIR/.aerospace.toml" "$HOME/.aerospace.toml"
    "$DOTFILES_DIR/reload.sh" --aerospace
}

install_karabiner() {
    log_info "Installing Karabiner Elements config..."
    mkdir -p "$HOME/.config/karabiner"
    create_symlink "$DOTFILES_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
    ensure_app_cli karabiner_cli \
        "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
    install_git_hooks
    "$DOTFILES_DIR/reload.sh" --karabiner
}

ensure_app_cli() {
    local name="$1" src="$2" target="/usr/local/bin/$1"
    [[ -x "$src" ]] || { log_warn "$name source missing: $src"; return; }
    [[ -L "$target" && "$(readlink "$target")" == "$src" ]] && return
    mkdir -p /usr/local/bin
    ln -sf "$src" "$target"
    log_info "Linked $target -> $src"
}

install_git_hooks() {
    log_info "Installing git hooks..."
    if [[ -d "$DOTFILES_DIR/.git/hooks" ]]; then
        ln -sf "$DOTFILES_DIR/hooks/pre-commit" "$DOTFILES_DIR/.git/hooks/pre-commit"
        log_info "Linked pre-commit hook"
    else
        log_warn "Not in a git repo, skipping hook installation"
    fi
}

install_hammerspoon() {
    log_info "Installing Hammerspoon config..."
    create_symlink "$DOTFILES_DIR/.hammerspoon" "$HOME/.hammerspoon"
    ensure_app_cli hs \
        "/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"
}

install_text_expander() {
    log_info "Installing text-expander config..."
    # Expander runs inside Hammerspoon (no app to install, no symlinks needed).
    # YAML files are read directly from $DOTFILES_DIR/text-expander/.
    if [[ ! -f "$DOTFILES_DIR/text-expander/personal.yml" ]]; then
        # Try importing from macOS text replacements first (works on a new
        # machine where iCloud has already synced entries from another device).
        # Falls back to interactive prompts if the DB is missing or empty.
        "$DOTFILES_DIR/text-expander/setup-personal.sh" --import \
            || "$DOTFILES_DIR/text-expander/setup-personal.sh"
    fi
    "$DOTFILES_DIR/reload.sh" --text-expander
}

install_fonts() {
    # MesloLGS NF — the font iTerm2 is configured to use and what
    # Powerlevel10k expects for its glyphs. Without it, prompt icons
    # render as question-mark boxes.
    log_info "Installing MesloLGS NF fonts..."
    local font_dir="$HOME/Library/Fonts"
    mkdir -p "$font_dir"
    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    local fonts=(
        "MesloLGS NF Regular.ttf"
        "MesloLGS NF Bold.ttf"
        "MesloLGS NF Italic.ttf"
        "MesloLGS NF Bold Italic.ttf"
    )
    for font in "${fonts[@]}"; do
        local target="$font_dir/$font"
        if [[ -f "$target" ]]; then
            log_info "$font already installed"
            continue
        fi
        local url="${base_url}/${font// /%20}"
        if curl -fsSL "$url" -o "$target"; then
            log_info "Installed $font"
        else
            log_error "Failed to download $font"
            rm -f "$target"
        fi
    done
}

install_iterm() {
    log_info "Installing iTerm2 config..."
    if [[ -f "$DOTFILES_DIR/com.googlecode.iterm2.plist" ]]; then
        # Backup existing preferences
        if [[ -f "$HOME/Library/Preferences/com.googlecode.iterm2.plist" ]]; then
            local backup="$HOME/Library/Preferences/com.googlecode.iterm2.plist.backup.$(date +%Y%m%d_%H%M%S)"
            log_warn "Backing up existing iTerm2 preferences to $backup"
            cp "$HOME/Library/Preferences/com.googlecode.iterm2.plist" "$backup"
        fi
        # Import preferences using defaults
        defaults import com.googlecode.iterm2 "$DOTFILES_DIR/com.googlecode.iterm2.plist"
        log_info "iTerm2 preferences imported. Restart iTerm2 to apply changes."
    else
        log_error "iTerm2 plist not found at $DOTFILES_DIR/com.googlecode.iterm2.plist"
    fi
}

register_login_items() {
    # AeroSpace registers itself via `start-at-login` in .aerospace.toml.
    # Karabiner runs as a system LaunchDaemon (installed by its pkg) — no
    # login item needed. Hammerspoon and Raycast do not auto-start, so add
    # them as login items here. Idempotent: skips apps already registered.
    log_info "Registering login items..."
    local existing
    existing=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null || true)
    for app in Hammerspoon Raycast; do
        local app_path="/Applications/${app}.app"
        if [[ ! -d "$app_path" ]]; then
            log_warn "${app}.app not found at $app_path, skipping login item"
            continue
        fi
        if echo "$existing" | grep -q "\\b${app}\\b"; then
            log_info "${app} already a login item"
        else
            osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"${app_path}\", hidden:false}" >/dev/null
            log_info "Added ${app} as login item"
        fi
    done
}

launch_apps() {
    # First-run launch so the user can grant Accessibility/Input Monitoring/
    # Driver Extension permissions in System Settings. `open` on an already-
    # running app is a no-op (just activates), so this is idempotent.
    log_info "Launching apps for first-run permission setup..."
    for app in Karabiner-Elements Hammerspoon Raycast AeroSpace; do
        local app_path="/Applications/${app}.app"
        [[ -d "$app_path" ]] || continue
        open "$app_path" && log_info "Opened ${app}"
    done
}

install_all() {
    install_brew
    install_oh_my_zsh
    install_shell
    install_git
    install_claude
    install_editor
    install_fonts
    install_aerospace
    install_karabiner
    install_hammerspoon
    install_text_expander
    install_iterm
    register_login_items
    launch_apps
}

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --all          Install all configs (default if no option specified)"
    echo "  --brew         Install Homebrew (if missing) and Brewfile packages"
    echo "  --oh-my-zsh    Install oh-my-zsh framework"
    echo "  --shell        Install shell configs (zshrc, bash_profile, p10k)"
    echo "  --git          Install git configs"
    echo "  --claude       Install global Claude Code config (~/.claude/CLAUDE.md)"
    echo "  --editor       Install editor configs (vim, tmux)"
    echo "  --fonts        Install MesloLGS NF fonts (for Powerlevel10k)"
    echo "  --aerospace    Install AeroSpace config"
    echo "  --karabiner    Install Karabiner Elements config"
    echo "  --hammerspoon  Install Hammerspoon config"
    echo "  --text-expander  Install text-expander config"
    echo "  --iterm        Install iTerm2 config"
    echo "  --login-items  Register Hammerspoon and Raycast as login items"
    echo "  --launch-apps  Open Karabiner-Elements, Hammerspoon, Raycast, AeroSpace"
    echo "  --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Install all configs (interactive)"
    echo "  $0 --karabiner      # Install only Karabiner config"
    echo "  $0 --shell --git    # Install shell and git configs"
}

# Parse arguments
if [[ $# -eq 0 ]]; then
    # No arguments - install all with confirmation
    echo "========================================"
    echo "Dotfiles Installation"
    echo "========================================"
    echo ""
    echo "This will create symlinks from your home directory to this repo."
    echo "Existing files will be backed up with a timestamp."
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi

    echo ""
    install_all
else
    # Parse specific options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                install_all
                shift
                ;;
            --brew)
                install_brew
                shift
                ;;
            --oh-my-zsh)
                install_oh_my_zsh
                shift
                ;;
            --shell)
                install_shell
                shift
                ;;
            --git)
                install_git
                shift
                ;;
            --claude)
                install_claude
                shift
                ;;
            --editor)
                install_editor
                shift
                ;;
            --fonts)
                install_fonts
                shift
                ;;
            --aerospace)
                install_aerospace
                shift
                ;;
            --karabiner)
                install_karabiner
                shift
                ;;
            --hammerspoon)
                install_hammerspoon
                shift
                ;;
            --text-expander)
                install_text_expander
                shift
                ;;
            --iterm)
                install_iterm
                shift
                ;;
            --login-items)
                register_login_items
                shift
                ;;
            --launch-apps)
                launch_apps
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
fi

echo ""
echo "========================================"
echo "Done!"
echo "========================================"
echo ""
echo "Manual steps (if needed):"
echo "  - Vimium C: Import settings from vimium_c.json"
echo "  - Stylus: Import styles from stylus/ directory"
echo "  - Keyboard layouts: Copy from keyboard-layouts/ to ~/Library/Keyboard Layouts/"
