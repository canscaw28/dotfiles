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
    "$DOTFILES_DIR/reload.sh" --karabiner
}

install_hammerspoon() {
    log_info "Installing Hammerspoon config..."
    create_symlink "$DOTFILES_DIR/.hammerspoon" "$HOME/.hammerspoon"
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

install_all() {
    install_shell
    install_git
    install_editor
    install_aerospace
    install_karabiner
    install_hammerspoon
    install_iterm
}

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --all          Install all configs (default if no option specified)"
    echo "  --shell        Install shell configs (zshrc, bash_profile, p10k)"
    echo "  --git          Install git configs"
    echo "  --editor       Install editor configs (vim, tmux)"
    echo "  --aerospace    Install AeroSpace config"
    echo "  --karabiner    Install Karabiner Elements config"
    echo "  --hammerspoon  Install Hammerspoon config"
    echo "  --iterm        Install iTerm2 config"
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
            --shell)
                install_shell
                shift
                ;;
            --git)
                install_git
                shift
                ;;
            --editor)
                install_editor
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
            --iterm)
                install_iterm
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
