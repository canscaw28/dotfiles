# All bindkey assignments live here. Widgets are defined in 10-selection.zsh
# and 20-history-nav.zsh; this file wires keys to them.

# --- cursor movement ----------------------------------------------------------
# Plain arrow keys (both normal and application mode)
bindkey "^[[D" move-char-left            # Left arrow (normal mode)
bindkey "^[[C" move-char-right           # Right arrow (normal mode)
bindkey "^[OD" move-char-left            # Left arrow (application mode)
bindkey "^[OC" move-char-right           # Right arrow (application mode)

# Smart up/down: history for single-line, cursor for multi-line,
# double-tap at boundary to navigate history (but not during key repeat)
bindkey "^[[A" smart-history-up          # Up arrow (normal mode)
bindkey "^[[B" smart-history-down        # Down arrow (normal mode)
bindkey "^[OA" smart-history-up          # Up arrow (application mode)
bindkey "^[OB" smart-history-down        # Down arrow (application mode)

bindkey "^[b" move-word-left             # Option+Left (Esc+b)
bindkey "^[f" move-word-right            # Option+Right (Esc+f)
bindkey "^A" move-to-line-start          # Ctrl+A (Caps+Y in iTerm2)
bindkey "^E" move-to-line-end            # Ctrl+E (Caps+O in iTerm2)

# --- selection ---------------------------------------------------------------
# Shift+arrow
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

# --- clipboard ---------------------------------------------------------------
# Copy selection without cutting (Alt+W / Esc+W)
bindkey "^[w" copy-region-as-kill
# Cut selection (Ctrl+W) - already default
# Paste (Ctrl+Y) - already default

# Caps+Cmd+C/X (via Karabiner sending F15/F16)
bindkey "^[[28~" copy-region-to-clipboard  # F15
bindkey "^[[29~" cut-region-to-clipboard   # F16

# Cmd+A select all, Cmd+C smart copy (via Karabiner iTerm2 overrides sending Option+key)
bindkey "^[a" select-all-buffer            # Option+A (Cmd+A and Caps+S+; in iTerm2)
bindkey "^[c" copy-or-interrupt            # Option+C (Cmd+C in iTerm2)

# Escape deselects if selection active
bindkey '\e' deselect-region

# --- history search ----------------------------------------------------------
# History navigation: Caps+, and Caps+M send Ctrl+P/Ctrl+N via Karabiner (iTerm2 only)
# Prefix-based history search - type partial command, then search matching history
bindkey "^P" history-beginning-search-backward  # Ctrl+P (Caps+, in iTerm2)
bindkey "^N" history-beginning-search-forward   # Ctrl+N (Caps+M in iTerm2)

# --- delete ------------------------------------------------------------------
bindkey "^?" backward-delete-char-or-region   # Backspace
bindkey "^[[3~" delete-char-or-region         # Delete key

# Delete to line above/below (Caps+D+K/J via Karabiner)
bindkey "^[[20;2~" delete-to-line-up          # Caps+D+K (F18 -> F9+Shift sequence)
bindkey "^[[19;2~" delete-to-line-down        # Caps+D+J (F19 -> F8+Shift sequence)
bindkey "^[k" backward-kill-line              # Option+K (Caps+D+Y in iTerm2)

# --- undo/redo ---------------------------------------------------------------
# Cmd+Z and Cmd+Shift+Z via Karabiner
bindkey "^_" undo                             # Ctrl+_ (Cmd+Z via Karabiner)
bindkey "\e_" redo                            # Meta+_ (Cmd+Shift+Z via Karabiner)
