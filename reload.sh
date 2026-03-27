#!/bin/bash

# Dotfiles reload script
# Reloads application configs that require explicit restart/reload

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

reload_aerospace() {
    log_info "Reloading AeroSpace config..."
    aerospace reload-config 2>/dev/null || log_error "AeroSpace not running or not installed"
    log_info "AeroSpace config reloaded"
}

reload_karabiner() {
    log_info "Reloading Karabiner Elements config..."
    launchctl kickstart -k "gui/$(id -u)/org.pqrs.service.agent.karabiner_console_user_server" 2>/dev/null || log_error "Karabiner Elements not running or not installed"
    touch "$HOME/.config/karabiner/karabiner.json" 2>/dev/null || true
    log_info "Karabiner Elements config reloaded"
}

reload_hammerspoon() {
    log_info "Reloading Hammerspoon config..."
    # hs.reload() restarts Hammerspoon, killing the IPC connection before
    # the CLI can read a response. Use hs.timer to defer the reload so
    # the IPC call returns cleanly first.
    /usr/local/bin/hs -c "hs.timer.doAfter(0.1, hs.reload)" 2>/dev/null || log_error "Hammerspoon not running or not installed"
    log_info "Hammerspoon config reloaded"
}

reload_iterm() {
    log_info "Reloading iTerm2 config..."
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$DOTFILES_DIR/com.googlecode.iterm2.plist" ]]; then
        defaults import com.googlecode.iterm2 "$DOTFILES_DIR/com.googlecode.iterm2.plist"
        log_info "iTerm2 config reloaded. Restart iTerm2 to apply changes."
    else
        log_error "iTerm2 plist not found at $DOTFILES_DIR/com.googlecode.iterm2.plist"
    fi
}

reload_espanso() {
    log_info "Reloading Espanso config..."
    espanso restart 2>/dev/null || log_error "Espanso not running or not installed"
    log_info "Espanso config reloaded"
}

reload_shell() {
    log_info "Shell config (.zshrc) cannot be reloaded from a script."
    log_info "Run this in your terminal: source ~/.zshrc"
}

reload_chrome() {
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    EXT_DIR="$DOTFILES_DIR/chrome-extensions/tab-mover"

    if [[ ! -d "$EXT_DIR" ]]; then
        log_error "Tab Mover extension not found at $EXT_DIR"
        return 1
    fi

    # Unpacked extensions are tracked by path in Secure Preferences
    local ext_found=false
    SECURE_PREFS="$HOME/Library/Application Support/Google/Chrome/Default/Secure Preferences"
    if [[ -f "$SECURE_PREFS" ]] && grep -q "chrome-extensions/tab-mover" "$SECURE_PREFS" 2>/dev/null; then
        ext_found=true
    fi

    if [[ "$ext_found" = false ]]; then
        log_error "Tab Mover Chrome extension is not installed."
        log_info "To install:"
        log_info "  1. Open chrome://extensions in Chrome"
        log_info "  2. Enable 'Developer mode' (top-right toggle)"
        log_info "  3. Click 'Load unpacked' → select $EXT_DIR"
        log_info "  4. Verify shortcuts at chrome://extensions/shortcuts"
        return 1
    fi

    log_info "Tab Mover Chrome extension is installed."
    log_info "To reload: click the refresh icon on chrome://extensions"
}

reload_all() {
    reload_aerospace
    reload_karabiner
    reload_hammerspoon
    reload_iterm
    reload_espanso
    reload_shell
    reload_chrome
}

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Reloads application configs without re-symlinking."
    echo "Useful after a git pull to pick up config changes."
    echo ""
    echo "Options:"
    echo "  --all          Reload all configs (default if no option specified)"
    echo "  --aerospace    Reload AeroSpace config"
    echo "  --karabiner    Reload Karabiner Elements config"
    echo "  --hammerspoon  Reload Hammerspoon config"
    echo "  --iterm        Reload iTerm2 config"
    echo "  --espanso      Reload Espanso config"
    echo "  --shell        Remind to source shell config (must be done manually)"
    echo "  --chrome       Check/notify Tab Mover Chrome extension status"
    echo "  --help         Show this help message"
}

# Parse arguments
if [[ $# -eq 0 ]]; then
    reload_all
else
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                reload_all
                shift
                ;;
            --aerospace)
                reload_aerospace
                shift
                ;;
            --karabiner)
                reload_karabiner
                shift
                ;;
            --hammerspoon)
                reload_hammerspoon
                shift
                ;;
            --iterm)
                reload_iterm
                shift
                ;;
            --espanso)
                reload_espanso
                shift
                ;;
            --shell)
                reload_shell
                shift
                ;;
            --chrome)
                reload_chrome
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
