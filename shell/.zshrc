ZSH_DISABLE_COMPFIX=true

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

USER=""
DEFAULT_USER=""

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH=$HOME/.oh-my-zsh
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

POWERLEVEL9K_ALWAYS_SHOW_CONTEXT=false
POWERLEVEL9K_ALWAYS_SHOW_USER=false
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
POWERLEVEL9K_SHORTEN_DELIMITER=".."
POWERLEVEL9K_SHORTEN_STRATEGY=(truncate_to_last truncate_absolute_chars)

POWERLEVEL9K_VCS_SHORTEN_LENGTH=4
POWERLEVEL9K_VCS_SHORTEN_MIN_LENGTH=4
POWERLEVEL9K_SHORTEN_DELIMITER=".."
POWERLEVEL9K_VCS_SHORTEN_STRATEGY="truncate_from_right"

ZDOTDIR=~/.cache/comp
source $ZSH/oh-my-zsh.sh
#source ~/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel9k.zsh-theme
#source ~/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme
#source ~/powerlevel10k/powerlevel10k.zsh-theme

autoload -Uz compinit
for dump in ~/.zcompdump(N.mh+24); do
  compinit
done
compinit -C


# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

# cd aliases
alias ..='cd ..'
alias .1='cd ..'
alias .2='.1 && .1'
alias .3='.2 && .1'
alias .4='.3 && .1'
alias .5='.4 && .1'
alias .6='.5 && .1'
alias .7='.6 && .1'
alias .8='.7 && .1'
alias .9='.8 && .1'

# ls aliases
alias p='pwd'
alias l='p && ls'
alias la='p && ls -a'
alias lh='p && ls -lah'

# git aliases
alias gm='git checkout master'
alias gn='git checkout -b '
alias gh='git checkout '
alias gb='git branch '
alias gd='git branch -D '
alias gl='git log'
alias gc='git commit -am "diff"'
alias gcm='git commit -am '
alias gp='git pull origin master'
alias gs='git stash'
alias gsa='git stash apply'
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# =============================================================================
# Visual Selection Mode (like GUI text editors)
# =============================================================================

# Enable visual highlighting for selected region
zle_highlight=(region:standout)

# Deselect helper - clears selection without side effects
function deselect-region() {
  REGION_ACTIVE=0
  zle -f vichange  # Clear visual feedback
}
zle -N deselect-region

# Movement wrappers - deselect before moving (like GUI editors)
function move-char-left() {
  if ((REGION_ACTIVE)); then
    REGION_ACTIVE=0
    MARK=$CURSOR  # Clear region by moving mark to cursor
  fi
  zle backward-char
}
zle -N move-char-left

function move-char-right() {
  if ((REGION_ACTIVE)); then
    REGION_ACTIVE=0
    MARK=$CURSOR
  fi
  zle forward-char
}
zle -N move-char-right

function move-word-left() {
  if ((REGION_ACTIVE)); then
    REGION_ACTIVE=0
    MARK=$CURSOR
  fi
  zle backward-word
}
zle -N move-word-left

function move-word-right() {
  if ((REGION_ACTIVE)); then
    REGION_ACTIVE=0
    MARK=$CURSOR
  fi
  zle forward-word
}
zle -N move-word-right

function move-to-line-start() {
  if ((REGION_ACTIVE)); then
    REGION_ACTIVE=0
    MARK=$CURSOR
  fi
  zle beginning-of-line
}
zle -N move-to-line-start

function move-to-line-end() {
  if ((REGION_ACTIVE)); then
    REGION_ACTIVE=0
    MARK=$CURSOR
  fi
  zle end-of-line
}
zle -N move-to-line-end

# Selection widgets - set mark if not selecting, then move
function select-char-left() {
  ((REGION_ACTIVE)) || zle set-mark-command
  zle backward-char
}
zle -N select-char-left

function select-char-right() {
  ((REGION_ACTIVE)) || zle set-mark-command
  zle forward-char
}
zle -N select-char-right

function select-word-left() {
  ((REGION_ACTIVE)) || zle set-mark-command
  zle backward-word
}
zle -N select-word-left

function select-word-right() {
  ((REGION_ACTIVE)) || zle set-mark-command
  zle forward-word
}
zle -N select-word-right

function select-to-line-start() {
  ((REGION_ACTIVE)) || zle set-mark-command
  zle beginning-of-line
}
zle -N select-to-line-start

function select-to-line-end() {
  ((REGION_ACTIVE)) || zle set-mark-command
  zle end-of-line
}
zle -N select-to-line-end

function select-line-up() {
  ((REGION_ACTIVE)) || zle set-mark-command
  local old_cursor=$CURSOR
  zle up-line
  # If on first line, move to start of buffer
  ((CURSOR == old_cursor)) && CURSOR=0
}
zle -N select-line-up

function select-line-down() {
  ((REGION_ACTIVE)) || zle set-mark-command
  local old_cursor=$CURSOR
  zle down-line
  # If on last line, move to end of buffer
  ((CURSOR == old_cursor)) && CURSOR=${#BUFFER}
}
zle -N select-line-down

# Select entire command buffer
function select-all-buffer() {
  MARK=0
  CURSOR=${#BUFFER}
  REGION_ACTIVE=1
}
zle -N select-all-buffer

# Line movement wrappers - position-aware history navigation
# At position 0: up/down navigate history (down falls back to cursor if no forward history)
# At end position: down navigates history forward
# Elsewhere: pure cursor movement
function move-line-up() {
  if ((REGION_ACTIVE)); then
    REGION_ACTIVE=0
    MARK=$CURSOR
  fi
  if ((CURSOR == 0)); then
    zle up-history
    CURSOR=0
  else
    zle up-line
  fi
}
zle -N move-line-up

function move-line-down() {
  if ((REGION_ACTIVE)); then
    REGION_ACTIVE=0
    MARK=$CURSOR
  fi
  if ((CURSOR == 0)); then
    # At start: try history forward, if none then move cursor down
    local old_buffer="$BUFFER"
    zle down-history
    if [[ "$BUFFER" == "$old_buffer" ]]; then
      zle down-line
    else
      CURSOR=0
    fi
  elif ((CURSOR == ${#BUFFER})); then
    # At end: history forward
    zle down-history
    CURSOR=0
  else
    # Try to move down; if on last line, go to end of buffer
    local old_cursor=$CURSOR
    zle down-line
    if ((CURSOR == old_cursor)); then
      CURSOR=${#BUFFER}
    fi
  fi
}
zle -N move-line-down

# Bind plain arrow keys (both normal and application mode)
bindkey "^[[D" move-char-left            # Left arrow (normal mode)
bindkey "^[[C" move-char-right           # Right arrow (normal mode)
bindkey "^[OD" move-char-left            # Left arrow (application mode)
bindkey "^[OC" move-char-right           # Right arrow (application mode)

# Smart up/down: history for single-line, cursor movement for multi-line,
# double-tap at boundary to navigate history (but not during key repeat)
autoload -Uz add-zle-hook-widget
typeset -g _HISTORY_NAV_PENDING=""
typeset -g _HISTORY_NAV_SAVED_BUFFER=""
typeset -g _HISTORY_NAV_SAVED_CURSOR=""
typeset -gF _NAV_LAST_UP_TIME=0
typeset -gF _NAV_LAST_DOWN_TIME=0
typeset -g _NAV_MODE=""  # "history" or "cursor"

# Cursor style helpers
_nav_cursor_normal() { echo -ne '\e[2 q'; }   # Steady block
_nav_cursor_pending() { echo -ne '\e[4 q'; }  # Steady underline

# Clear pending state
_nav_clear_pending() {
  [[ -n "$_HISTORY_NAV_PENDING" ]] && { _HISTORY_NAV_PENDING=""; _nav_cursor_normal; }
}

# Enter pending state at boundary
_nav_enter_pending() {  # $1=direction, $2=cursor_pos
  CURSOR=$2
  _HISTORY_NAV_PENDING=$1
  _HISTORY_NAV_SAVED_BUFFER="$BUFFER"
  _HISTORY_NAV_SAVED_CURSOR=$CURSOR
  _nav_cursor_pending
}

# Navigate history and set mode
_nav_do_history() {  # $1=direction
  _nav_clear_pending
  [[ $1 == "up" ]] && zle up-history || zle down-history
  CURSOR=0
  _NAV_MODE="history"
}

# Reset state on new line
_reset_history_nav_state() {
  _nav_clear_pending
  _NAV_MODE=""
}
add-zle-hook-widget line-init _reset_history_nav_state

# Clear pending state when buffer/cursor changes
_check_history_nav_pending() {
  [[ -n "$_HISTORY_NAV_PENDING" ]] && \
    { [[ "$BUFFER" != "$_HISTORY_NAV_SAVED_BUFFER" ]] || ((CURSOR != _HISTORY_NAV_SAVED_CURSOR)) } && \
    _nav_clear_pending
}
add-zle-hook-widget line-pre-redraw _check_history_nav_pending

# Core navigation logic - $1=direction (up/down)
_smart_history_nav() {
  local dir=$1
  local time_var="_NAV_LAST_${dir:u}_TIME"
  local at_boundary boundary_pos text_to_check

  # Clear selection
  ((REGION_ACTIVE)) && { REGION_ACTIVE=0; MARK=$CURSOR; }

  # Detect key repeat (< 200ms = repeat)
  local current_time=${EPOCHREALTIME}
  local is_repeat=$(( (current_time - ${(P)time_var}) * 1000 < 200 ))
  : ${(P)time_var::=$current_time}

  # Reset mode on new press
  ((is_repeat)) || _NAV_MODE=""

  # Check boundary position
  if [[ $dir == "up" ]]; then
    text_to_check="${BUFFER:0:$CURSOR}"
    at_boundary=$([[ "$text_to_check" != *$'\n'* ]] && echo 1 || echo 0)
    boundary_pos=0
  else
    text_to_check="${BUFFER:$CURSOR}"
    at_boundary=$([[ "$text_to_check" != *$'\n'* ]] && echo 1 || echo 0)
    boundary_pos=${#BUFFER}
  fi

  # Repeat in history mode - keep navigating
  if ((is_repeat)) && [[ "$_NAV_MODE" == "history" ]]; then
    [[ $dir == "up" ]] && zle history-beginning-search-backward || zle history-beginning-search-forward
    return
  fi

  # Repeat in cursor mode
  if ((is_repeat)) && [[ "$_NAV_MODE" == "cursor" ]]; then
    if ((at_boundary)); then
      [[ "$_HISTORY_NAV_PENDING" == "$dir" ]] && { _nav_do_history $dir; return; }
      _nav_enter_pending $dir $boundary_pos
    else
      [[ $dir == "up" ]] && zle up-line || zle down-line
    fi
    return
  fi

  # New press: check for pending double-tap
  [[ "$_HISTORY_NAV_PENDING" == "$dir" ]] && { _nav_do_history $dir; return; }
  _nav_clear_pending

  # Single-line: navigate history directly
  if [[ "$BUFFER" != *$'\n'* ]]; then
    _NAV_MODE="history"
    [[ $dir == "up" ]] && zle history-beginning-search-backward || zle history-beginning-search-forward
    return
  fi

  # Multi-line: cursor mode
  _NAV_MODE="cursor"
  if ((at_boundary)); then
    _nav_enter_pending $dir $boundary_pos
  else
    [[ $dir == "up" ]] && zle up-line || zle down-line
  fi
}

smart-history-up() { _smart_history_nav up; }
smart-history-down() { _smart_history_nav down; }
zle -N smart-history-up
zle -N smart-history-down

bindkey "^[[A" smart-history-up          # Up arrow (normal mode)
bindkey "^[[B" smart-history-down        # Down arrow (normal mode)
bindkey "^[OA" smart-history-up          # Up arrow (application mode)
bindkey "^[OB" smart-history-down        # Down arrow (application mode)
bindkey "^[b" move-word-left             # Option+Left (Esc+b)
bindkey "^[f" move-word-right            # Option+Right (Esc+f)
bindkey "^A" move-to-line-start          # Ctrl+A (Caps+Y in iTerm2)
bindkey "^E" move-to-line-end            # Ctrl+E (Caps+O in iTerm2)

# Bind shift+arrow to selection
bindkey "^[[1;2D" select-char-left       # Shift+Left
bindkey "^[[1;2C" select-char-right      # Shift+Right
bindkey "^[[1;2A" select-line-up         # Shift+Up
bindkey "^[[1;2B" select-line-down       # Shift+Down

# Word and line selection (via Karabiner iTerm2 overrides)
bindkey "^[[1;6D" select-word-left       # Ctrl+Shift+Left
bindkey "^[[1;6C" select-word-right      # Ctrl+Shift+Right
bindkey "^[[1;6A" select-line-up         # Ctrl+Shift+Up (Caps+S+K in iTerm2)
bindkey "^[[1;6B" select-line-down       # Ctrl+Shift+Down (Caps+S+J in iTerm2)
bindkey "^[[1;2H" select-to-line-start   # Shift+Home
bindkey "^[[1;2F" select-to-line-end     # Shift+End

# Copy selection without cutting (Alt+W / Esc+W)
bindkey "^[w" copy-region-as-kill
# Cut selection (Ctrl+W) - already default
# Paste (Ctrl+Y) - already default

# Clipboard operations (copy/cut to system clipboard via pbcopy)
function copy-region-to-clipboard() {
  if ((REGION_ACTIVE)); then
    zle copy-region-as-kill
    print -rn -- "$CUTBUFFER" | pbcopy
    REGION_ACTIVE=0
  fi
}
zle -N copy-region-to-clipboard

function cut-region-to-clipboard() {
  if ((REGION_ACTIVE)); then
    zle kill-region
    print -rn -- "$CUTBUFFER" | pbcopy
  fi
}
zle -N cut-region-to-clipboard

# Smart copy - copies selection if active, otherwise sends Ctrl+C (interrupt)
function copy-or-interrupt() {
  if ((REGION_ACTIVE)); then
    zle copy-region-as-kill
    print -rn -- "$CUTBUFFER" | pbcopy
    REGION_ACTIVE=0
  else
    zle send-break  # Ctrl+C interrupt
  fi
}
zle -N copy-or-interrupt

# Bind Caps+Cmd+C/X (via Karabiner sending F15/F16)
bindkey "^[[28~" copy-region-to-clipboard  # F15
bindkey "^[[29~" cut-region-to-clipboard   # F16

# Cmd+A select all, Cmd+C smart copy (via Karabiner iTerm2 overrides sending Option+key)
bindkey "^[a" select-all-buffer            # Option+A (Cmd+A and Caps+S+; in iTerm2)
bindkey "^[c" copy-or-interrupt            # Option+C (Cmd+C in iTerm2)

# Escape deselects if selection active
function deselect-region() {
  if ((REGION_ACTIVE)); then
    REGION_ACTIVE=0
    MARK=$CURSOR
  fi
}
zle -N deselect-region
bindkey '\e' deselect-region               # Escape to deselect

# History navigation: Caps+, and Caps+M send Ctrl+P/Ctrl+N via Karabiner (iTerm2 only)
# Prefix-based history search - type partial command, then search matching history
bindkey "^P" history-beginning-search-backward  # Ctrl+P (Caps+, in iTerm2)
bindkey "^N" history-beginning-search-forward   # Ctrl+N (Caps+M in iTerm2)

# Backspace/Delete wrappers - delete selection if active
function backward-delete-char-or-region() {
  if ((REGION_ACTIVE)); then
    zle kill-region
  else
    zle backward-delete-char
  fi
}
zle -N backward-delete-char-or-region

function delete-char-or-region() {
  if ((REGION_ACTIVE)); then
    zle kill-region
  else
    zle delete-char
  fi
}
zle -N delete-char-or-region

bindkey "^?" backward-delete-char-or-region   # Backspace
bindkey "^[[3~" delete-char-or-region         # Delete key

# Delete to line above/below (Caps+D+K/J via Karabiner)
# Uses up-line/down-line (not -or-history) to avoid navigating command history
function delete-to-line-up() {
  zle set-mark-command
  zle up-line || return  # Do nothing if already at top line
  zle kill-region
}
zle -N delete-to-line-up

function delete-to-line-down() {
  zle set-mark-command
  zle down-line || return  # Do nothing if already at bottom line
  zle kill-region
}
zle -N delete-to-line-down

bindkey "^[[20;2~" delete-to-line-up          # Caps+D+K (F18 -> F9+Shift sequence)
bindkey "^[[19;2~" delete-to-line-down        # Caps+D+J (F19 -> F8+Shift sequence)

# Undo/Redo (Cmd+Z and Cmd+Shift+Z via Karabiner)
bindkey "^_" undo                             # Ctrl+_ (Cmd+Z via Karabiner)
bindkey "\e_" redo                            # Meta+_ (Cmd+Shift+Z via Karabiner)

export PATH="$HOME/.local/bin:$PATH"

# Track when .zshrc was sourced (for stale config indicator in prompt)
# Resolve symlink to get actual file path for reliable mtime checking
export ZSHRC_REAL_PATH=$(readlink ~/.zshrc || echo ~/.zshrc)
export ZSHRC_SOURCED_MTIME=$(stat -f %m "$ZSHRC_REAL_PATH" 2>/dev/null)

