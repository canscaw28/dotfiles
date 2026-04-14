# Smart history / cursor navigation for up/down arrows
#
# Single-line buffer: up/down navigates command history (prefix search).
# Multi-line buffer: up/down moves the cursor between lines.
# At a buffer boundary (top line when pressing up, bottom line when pressing
# down): the first press enters a "pending" state shown by a block cursor;
# a second press in the same direction navigates history.
# During key auto-repeat, mode (history vs cursor) is sticky within a burst.
#
# Line movement wrappers are position-aware: at CURSOR=0, up navigates
# history; at CURSOR=end, down navigates history; otherwise they move
# the cursor normally.

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

autoload -Uz add-zle-hook-widget
typeset -g _HISTORY_NAV_PENDING=""
typeset -g _HISTORY_NAV_SAVED_BUFFER=""
typeset -g _HISTORY_NAV_SAVED_CURSOR=""
typeset -gF _NAV_LAST_UP_TIME=0
typeset -gF _NAV_LAST_DOWN_TIME=0
typeset -g _NAV_MODE=""  # "history" or "cursor"

# Cursor style helpers
_nav_cursor_normal() { echo -ne '\e[6 q'; }   # Steady bar (vertical)
_nav_cursor_pending() { echo -ne '\e[2 q'; }  # Steady block
_nav_cursor_normal  # Set initial cursor style

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
