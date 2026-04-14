# Visual Selection Mode (like GUI text editors)
#
# Widgets that manage a highlighted region:
# - movement widgets deselect before moving
# - selection widgets set the mark if not already selecting, then move
# - clipboard widgets copy/cut the region to the system pasteboard
# - backspace/delete widgets remove the region if active
#
# Keybindings for all of these live in 30-keybindings.zsh.

# Enable visual highlighting for selected region
zle_highlight=(region:standout)

# Deselect helper - clears selection without side effects
function deselect-region() {
  if ((REGION_ACTIVE)); then
    REGION_ACTIVE=0
    MARK=$CURSOR
  fi
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

# Delete to line above/below
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
