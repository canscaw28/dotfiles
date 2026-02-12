# Karabiner Elements Configuration

## Design Philosophy

This configuration turns **Caps Lock** into an ergonomic command system built around two core ideas: the left hand selects *what* to do (context), the right hand selects *where* to do it (action) — and both hands require minimal unique muscle memory.

### Left Hand: Layers and Modes

The left hand operates on a three-tier hierarchy, mapped to finger anatomy:

1. **Pinky → Caps Lock (always held)** activates the entire system. Every shortcut starts here.
2. **Pointer finger → Layer selection.** A layer is a top-level domain — a completely different context for the right hand's actions. Each layer key is held by the pointer finger:

   | Pointer Position | Layer | Domain |
   | --- | --- | --- |
   | *(home / absent)* | Default | Cursor movement |
   | F | Scroll | Page scrolling via HammerSpoon |
   | G | Chrome | Browser tab control |
   | T | Aerospace | Window focus, movement, and joining |
   | R | Workspace | Workspace switching and window dispatch |

3. **Middle and ring fingers → Mode selection.** A mode is a *variation within a layer* — it changes how the right hand's actions are interpreted without changing the domain. Mode keys are ergonomically adjacent to the pointer finger's layer key, so they fall naturally under the middle or ring finger:

   | Layer | Mode Key | Mode | Description |
   | --- | --- | --- | --- |
   | Default | *(none)* | Cursor | Move the cursor |
   | Default | S (ring) | Selection | Select text instead of moving |
   | Default | D (middle) | Deletion | Delete text instead of moving |
   | Chrome (G) | *(none)* | Tab Navigation | Switch between tabs |
   | Chrome (G) | F (middle) | Tab Movement | Physically reorder tabs |
   | Aerospace (T) | *(none)* | Focus | Focus windows directionally |
   | Aerospace (T) | R (ring) | Move | Move windows directionally |
   | Aerospace (T) | R+E (ring+middle) | Join | Join windows directionally |
   | Workspace (R) | *(none)* | Focus | Focus workspace on current display |
   | Workspace (R) | E (middle) | Move | Move window to workspace (stay) |
   | Workspace (R) | E+W (middle+ring) | Move+Follow | Move window + follow on current display |
   | Workspace (R) | Q (pinky) | Swap | Swap current and selected workspaces between monitors |
   | Workspace (R) | Q+E (pinky+middle) | Swap+Follow | Swap workspaces, then focus the selected workspace |

   Notice that S and D are not separate layers — they are **modes of the Default layer**. The pointer finger is absent (no layer key held), so the middle and ring fingers are free to select a mode on the home row. Similarly, F is not a mode of Chrome — it's a mode key for the G layer, pressed by the middle finger while the pointer holds G.

   Mode keys are always relative to the pointer finger's position:
   - **Default layer** (pointer absent): modes use home-row neighbors **S**, **D**
   - **G layer** (pointer on G): modes use **F**, and potentially **D**, **V**, **B**
   - **T layer** (pointer on T): modes could use **R**, **E**, **W**, or **D**, **S**, **3**, **4**
   - **R layer** (pointer on R): modes use **E**, **W**, **Q**

   This means learning a new layer doesn't require memorizing arbitrary modifier keys — the mode keys are always "the fingers next to the layer key."

### Right Hand: Consistent Action Layout

Regardless of which layer or mode the left hand selects, the right hand uses the **same spatial layout**:

```
     Y  U  I  O              ← extreme actions (amplified h/j/k/l)
       H  J  K  L            ← directional core (←↓↑→)
         N  M  ,  .          ← contextual extensions
```

The directional keys mirror vim:
- **H / L** — left / right (single step)
- **J / K** — down / up (or the closest conceptual equivalent)
- **Y / O** — far left / far right (jump to boundary)
- **U / I** — big step left / big step right (intermediate jump)

This mapping is consistent across layers and modes:

| Layer | Mode | H / L | U / I | Y / O |
| --- | --- | --- | --- | --- |
| Default | Cursor | ← / → | word left / right | line start / end |
| Default | Selection (S) | select ← / → | select word left / right | select to line start / end |
| Default | Deletion (D) | delete ← / → | delete word left / right | delete to line start / end |
| Chrome | Navigation (G) | prev / next tab | jump 3 tabs | first / last tab |
| Chrome | Movement (F+G) | move tab ← / → | move tab 3 positions | move to start / end |
| Aerospace | Focus (T) | focus ← / → | | |
| Aerospace | Move (R+T) | move window ← / → | | |
| Aerospace | Join (R+E+T) | join ← / → | | |

Because the right hand layout never changes, you only learn it once. Switching layers and modes is entirely a left-hand concern.

### Why This Works

- **Right hand** — near-zero unique muscle memory. The same finger movements mean analogous actions in every context. "H always goes left. Y always goes to the far left."
- **Left hand** — layers have unique keys, but modes cluster naturally around the pointer finger. Selecting a layer and its mode is a single comfortable hand shape, not a sequence to memorize.
- **Scalability** — new layers and modes slot in without disrupting existing muscle memory. A new mode on the G layer just means one more adjacent finger; a new layer means a new pointer position. The right hand actions carry over automatically.

---

## Layers and Modes

| Layer | Layer Key | Mode Key | Mode | Description |
| --- | --- | --- | --- | --- |
| Default | ⇪ | — | Cursor | Move the cursor |
| | ⇪ | S | Selection | Select text instead of moving |
| | ⇪ | D | Deletion | Delete text instead of moving |
| Scroll | ⇪ + F | — | — | Page scrolling via HammerSpoon |
| Chrome | ⇪ + G | — | Navigation | Switch between tabs |
| | ⇪ + G | F | Movement | Physically reorder tabs |
| Aerospace | ⇪ + T | — | Focus | Window focus management |
| | ⇪ + T | R | Move | Move windows directionally |
| | ⇪ + T | R+E | Join | Join windows directionally |
| Workspace | ⇪ + R | — | Focus | Focus workspace on current display |
| | ⇪ + R | E | Move | Move window to workspace (stay) |
| | ⇪ + R | E+W | Move+Follow | Move window + follow on current display |
| | ⇪ + R | Q | Swap | Swap current and selected workspaces between monitors |
| | ⇪ + R | Q+E | Swap+Follow | Swap workspaces, then focus the selected workspace |
| *(unassigned)* | ⇪ + A | | | |

*Available layer keys: Z, X, C, V, B*

## Misc Shortcuts

| Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + ⇪ | ⌃ + ⌃ | Trigger LanguageTool tooltip |
| ⇪ + R⇧ | ⇪ | Trigger Caps-Lock |

---

## Default Layer (⇪)

### Cursor Movement

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + H | ← | Move cursor to the left |
| ⇪ + J | ↓ | Move cursor down |
| ⇪ + K | ↑ | Move cursor up |
| ⇪ + L | →  | Move cursor to the right |
| ⇪ + ; | Esc | Easy to reach Esc key alternative |
| ⇪ + Y | ⌘ + ← | Jumps cursor to the start of the line |
| ⇪ + U | ⌥ + ← | Jump back one word |
| ⇪ + I | ⌥ + → | Jump forward one word |
| ⇪ + O | ⌘ + → | Jumps cursor to the end of the line |
| ⇪ + P |  |  |
| ⇪ + N |  |  |
| ⇪ + M | ⌘ + ↓ | Moves cursor to the bottom of an input field |
| ⇪ + , | ⌘ + ↑ | Moves cursor to the top of an input field |
| ⇪ + . |  |  |
| ⇪ + / |  |  |

### Selection Mode (⇪ + S)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + S + H | ⇧ + ← | Select text left one character |
| ⇪ + S + J | ⇧ + ↓ | Select text downwards |
| ⇪ + S + K | ⇧ + ↑ | Select text upwards |
| ⇪ + S + L | ⇧ + →  | Select text right one character |
| ⇪ + S + ; | ⌘ + A | Select the entire text field |
| ⇪ + S + Y | ⌘ + ⇧ + ← | Select text to the start of the line |
| ⇪ + S + U | ⌥ + ⇧ + ← | Select the word to the left |
| ⇪ + S + I | ⌥ + ⇧ + → | Select the word to the right |
| ⇪ + S + O | ⌘ + ⇧ + → | Select text to the end of the line |
| ⇪ + S + P | ⌘ + ←, ⌘ + ⇧ + → | Select the entire line |
| ⇪ + S + N |  |  |
| ⇪ + S + M | ⌥ + ⇧ + ↓ | Moves cursor to the bottom of an input field |
| ⇪ + S + , | ⌥ + ⇧ + ↑ | Moves cursor to the top of an input field |
| ⇪ + S + . |  |  |
| ⇪ + S + / |  |  |

### Deletion Mode (⇪ + D)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + D + H | ⌫ | Delete one character to the left |
| ⇪ + D + J | ⇧ + ↓, ⌫ | Delete the line down from the cursor |
| ⇪ + D + K | ⇧ + ↑, ⌫ | Delete the line up from the cursor |
| ⇪ + D + L | ⌦ | Delete one character to the right |
| ⇪ + D + ; | ⌘ + A, ⌫ | Delete whole text area |
| ⇪ + D + Y | ⌘ + ⌫ | Delete the line to the left |
| ⇪ + D + U | ⌥ + ⌫ | Delete the word to the left |
| ⇪ + D + I | ⌥ + ⌦ | Delete the word to the right |
| ⇪ + D + O | ⌘ + ⇧ + →, ⌫ | Delete the line to the right |
| ⇪ + D + P | ⌘ + →, ⌘ + ⌫ | Delete the whole line |
| ⇪ + D + N |  |  |
| ⇪ + D + M | ⌃ + K | Delete the paragraph down from the cursor |
| ⇪ + D + , | ⌥ + ⇧ + ↑, ⌫ | Delete the paragraph up from the cursor |
| ⇪ + D + . |  |  |
| ⇪ + D + / |  |  |

---

## Scroll Layer (⇪ + F)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + F + H | ⌃ + ` | HS: Scroll down |
| ⇪ + F + J | ⌃ + 1 | HS: Scroll up |
| ⇪ + F + K | ⌃ + 2 | HS: Scroll left |
| ⇪ + F + L | ⌃ + 3 | HS: Scroll right |
| ⇪ + F + ; | ⌃ + 4 | HS: Scroll half a page down |
| ⇪ + F + Y | ⌃ + 5 | HS: Scroll half a page up |
| ⇪ + F + U | ⌃ + 6 | HS: Scroll a full page down |
| ⇪ + F + I | ⌃ + 7 | HS: Scroll a full page up |
| ⇪ + F + O | ⌃ + 8 | HS: Scroll to the bottom |
| ⇪ + F + P | ⌃ + 9 | HS: scroll to the top |
| ⇪ + F + N | ⌃ + 0 | HS: move cursor near right center of window |
| ⇪ + F + M |  |  |
| ⇪ + F + , |  |  |
| ⇪ + F + . |  |  |
| ⇪ + F + / |  |  |

---

## Chrome Layer (⇪ + G)

### Tab Navigation

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + G + H | ⌘ + ⌥ + ← | Previous tab |
| ⇪ + G + L | ⌘ + ⌥ + → | Next tab |
| ⇪ + G + Y | ⌘ + 1 | First tab |
| ⇪ + G + O | ⌘ + 9 | Last tab |
| ⇪ + G + ; | Esc; T | Trigger Vimium Tab search |
| ⇪ + G + ' | Esc; o | Trigger Vimium history search |
| ⇪ + G + P | Esc; yt | Trigger Vimium Duplicate tab |
| ⇪ + G + [ | ⌘ + ← | Move back in history |
| ⇪ + G + ] | ⌘ + → | Move forward in history |
| ⇪ + G + / | ⌘ + W | Close current tab |
| ⇪ + G + J | *available* | |
| ⇪ + G + K | *available* | |
| ⇪ + G + U | ⌘ + ⌥ + ← ×3 | Jump 3 tabs left |
| ⇪ + G + I | ⌘ + ⌥ + → ×3 | Jump 3 tabs right |
| ⇪ + G + N | *available* | |
| ⇪ + G + M | *available* | |
| ⇪ + G + , | *available* | |
| ⇪ + G + . | *available* | |

### Tab Movement Mode (⇪ + F + G)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + F + G + H | Esc; << | Move tab one position to the left |
| ⇪ + F + G + L | Esc; >> | Move tab one position to the right |
| ⇪ + F + G + Y | Esc; 100<< | Move tab to the beginning |
| ⇪ + F + G + O | Esc; 100>> | Move tab to the end |
| ⇪ + F + G + J | *available* | |
| ⇪ + F + G + K | *available* | |
| ⇪ + F + G + U | Esc; 3<< | Move tab 3 positions to the left |
| ⇪ + F + G + I | Esc; 3>> | Move tab 3 positions to the right |
| ⇪ + F + G + P | *available* | |
| ⇪ + F + G + ; | *available* | |
| ⇪ + F + G + ' | *available* | |
| ⇪ + F + G + N | *available* | |
| ⇪ + F + G + M | *available* | |
| ⇪ + F + G + , | *available* | |
| ⇪ + F + G + . | *available* | |
| ⇪ + F + G + / | *available* | |

---

## Aerospace Layer (⇪ + T)

### Focus

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + T + H | ⌘ + ⌥ + ⌃ + H | Focus left  |
| ⇪ + T + J | ⌘ + ⌥ + ⌃ + J | Focus down |
| ⇪ + T + K | ⌘ + ⌥ + ⌃ + K | Focus up |
| ⇪ + T + L | ⌘ + ⌥ + ⌃ + L | Focus right |
| ⇪ + T + ; | ⌘ + ⌥ + ⌃ + ; | Mode service (esc to reload, r to flatten, f to float) |
| ⇪ + T + ' | ⌘ + ⌥ + ⌃ + ' | Switch to previous workspace (back-and-forth) |
| ⇪ + T + - | ⌘ + ⌥ + ⌃ + ⇧ + - | Resize smart -50 |
| ⇪ + T + = | ⌘ + ⌥ + ⌃ + ⇧ + = | Resize smart +50 |
| ⇪ + T + P | *available* | |
| ⇪ + T + Y | *available* | |
| ⇪ + T + U | *available* | |
| ⇪ + T + I | *available* | |
| ⇪ + T + O | *available* | |
| ⇪ + T + N | *available* | |
| ⇪ + T + M | *available* | |
| ⇪ + T + , | *available* | |
| ⇪ + T + . | *available* | |

### Move Mode (⇪ + R + T)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + R + T + H | ⌘ + ⌥ + ⌃ + Y | Move window left |
| ⇪ + R + T + J | ⌘ + ⌥ + ⌃ + U | Move window down |
| ⇪ + R + T + K | ⌘ + ⌥ + ⌃ + I | Move window up |
| ⇪ + R + T + L | ⌘ + ⌥ + ⌃ + O | Move window right |
| ⇪ + R + T + Y | *available* | |
| ⇪ + R + T + U | *available* | |
| ⇪ + R + T + I | *available* | |
| ⇪ + R + T + O | *available* | |
| ⇪ + R + T + P | *available* | |
| ⇪ + R + T + ; | *available* | |
| ⇪ + R + T + ' | *available* | |
| ⇪ + R + T + N | *available* | |
| ⇪ + R + T + M | *available* | |
| ⇪ + R + T + , | *available* | |
| ⇪ + R + T + . | *available* | |
| ⇪ + R + T + / | *available* | |

### Join Mode (⇪ + R + E + T)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + R + E + T + H | ⌘ + ⌥ + ⌃ + N | Join with left |
| ⇪ + R + E + T + J | ⌘ + ⌥ + ⌃ + M | Join with down |
| ⇪ + R + E + T + K | ⌘ + ⌥ + ⌃ + , | Join with up |
| ⇪ + R + E + T + L | ⌘ + ⌥ + ⌃ + . | Join with right |
| ⇪ + R + E + T + Y | *available* | |
| ⇪ + R + E + T + U | *available* | |
| ⇪ + R + E + T + I | *available* | |
| ⇪ + R + E + T + O | *available* | |
| ⇪ + R + E + T + P | *available* | |
| ⇪ + R + E + T + ; | *available* | |
| ⇪ + R + E + T + ' | *available* | |
| ⇪ + R + E + T + N | *available* | |
| ⇪ + R + E + T + M | *available* | |
| ⇪ + R + E + T + , | *available* | |
| ⇪ + R + E + T + . | *available* | |
| ⇪ + R + E + T + / | *available* | |

---

## Workspace Layer (⇪ + R)

Workspace operations execute directly via Karabiner `shell_command` (calling `ws.sh`), bypassing AeroSpace keybindings entirely. This avoids modifier conflicts with app shortcuts like `Cmd+Shift+H`.

20 workspaces mapped to a right-hand grid (workspaces float freely between displays):

```
6  7  8  9  0
y  u  i  o  p
h  j  k  l  ;
n  m  ,  .  /
```

### Focus (⇪ + R)

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + R + *key* | Switch to workspace on the currently focused monitor |

### Move Window (⇪ + R + E)

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + R + E + *key* | Move focused window to workspace (stay on current) |

### Move + Follow (⇪ + R + E + W)

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + R + E + W + *key* | Move window to workspace and follow it on current display |

### Swap (⇪ + R + Q)

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + R + Q + *key* | Swap current workspace with selected workspace between monitors |

### Swap + Follow (⇪ + R + Q + E)

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + R + Q + E + *key* | Swap workspaces between monitors, then focus the selected workspace |

### Quote Key Monitor Operations

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + R + ' | Swap workspaces between current and next monitor |
| ⇪ + R + E + ' | Move focused window to next monitor |
| ⇪ + R + E + W + ' | Move focused window to next monitor and follow |

### Swap Implementation

Swap operations use `summon-workspace` with an empty buffer workspace (`~`) to avoid visual jitter. AeroSpace's `move-workspace-to-monitor` internally refocuses the moved workspace, causing random workspaces to flash on the source monitor. The summon-based approach only shows `~` (empty) as an intermediate state.

The `on-focus-changed` callback is deliberately disabled in `.aerospace.toml` — it fires on every intermediate focus change during swaps, causing AeroSpace to drop commands. Instead, `move-mouse window-lazy-center` is called explicitly at the end of each operation in `ws.sh`, `smart-focus.sh`, and `smart-move.sh`.

A shared PID-based lock (`/tmp/aerospace-lock.pid`) prevents concurrent aerospace script execution. Stale locks from killed processes are automatically cleaned up.

### Window State Preservation

Window-to-workspace assignments are automatically saved after every workspace operation. On AeroSpace restart, windows are restored to their previous workspaces by matching on app name and window title.

---

## iTerm2-Specific Overrides

*These bindings override the standard behavior when iTerm2 is the frontmost application, using terminal-compatible key sequences.*

### Cursor Movement (iTerm2)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + H | ← | Move cursor left |
| ⇪ + J | ↓ | Smart down: history for single-line, cursor for multi-line |
| ⇪ + K | ↑ | Smart up: history for single-line, cursor for multi-line |
| ⇪ + L | → | Move cursor right |
| ⇪ + Y | ⌃ + A | Jump to start of line |
| ⇪ + U | ⌥ + ← | Jump back one word |
| ⇪ + I | ⌥ + → | Jump forward one word |
| ⇪ + O | ⌃ + E | Jump to end of line |

*⇪+J/K use smart navigation: on single-line commands they navigate history with prefix search. On multi-line commands they move the cursor, with double-tap at boundaries to switch to history navigation.*

### History Navigation (iTerm2)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + , | ⌃ + P | Search history backward with prefix matching |
| ⇪ + M | ⌃ + N | Search history forward with prefix matching |

*Type a partial command, then use these keys to find matching history entries (e.g., type "git" then ⇪+, to find commands starting with "git").*

### Text Deletion (iTerm2)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + D + Y | ⌃ + U | Delete from cursor to start of line |
| ⇪ + D + U | ⌃ + W | Delete word to the left |
| ⇪ + D + I | Esc, d | Delete word to the right |
| ⇪ + D + O | ⌃ + K | Delete from cursor to end of line |
| ⇪ + D + J | F18 | Delete to line below |
| ⇪ + D + K | F19 | Delete to line above |

### Undo/Redo (iTerm2)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⌘ + Z | ⌃ + _ | Undo last text change |
| ⌘ + ⇧ + Z | Esc + _ | Redo last undo |

### Text Selection (iTerm2)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + S + H | ⇧ + ← | Select character to the left |
| ⇪ + S + J | ⌃ + ⇧ + ↓ | Select line down (to end of buffer on last line) |
| ⇪ + S + K | ⌃ + ⇧ + ↑ | Select line up (to start of buffer on first line) |
| ⇪ + S + L | ⇧ + → | Select character to the right |
| ⇪ + S + Y | ⇧ + Home | Select to start of line |
| ⇪ + S + U | ⌃ + ⇧ + ← | Select word to the left |
| ⇪ + S + I | ⌃ + ⇧ + → | Select word to the right |
| ⇪ + S + O | ⇧ + End | Select to end of line |
| ⇪ + S + ; | ⌥ + A | Select entire command buffer |

### Standard Commands (iTerm2)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⌘ + A | ⌥ + A | Select entire command buffer (not terminal output) |
| ⌘ + C | ⌥ + C | Copy selection if active, else Ctrl+C interrupt |

### Clipboard Operations (iTerm2)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + ⌘ + C | F15 | Copy selection to system clipboard |
| ⇪ + ⌘ + X | F16 | Cut selection to system clipboard |

### G Layer - Tmux Pane Navigation (iTerm2)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + G + H | ⌃ + B, ← | Select tmux pane left |
| ⇪ + G + J | ⌃ + B, ↓ | Select tmux pane down |
| ⇪ + G + K | ⌃ + B, ↑ | Select tmux pane up |
| ⇪ + G + L | ⌃ + B, → | Select tmux pane right |

---

## HammerSpoon

*These keys are widely available for remapping*

| Key / Shortcut | Description |
| --- | --- |
| ⌃ + ` | Scroll down |
| ⌃ + 1 | Scroll up |
| ⌃ + 2 | Scroll left |
| ⌃ + 3 | Scroll right |
| ⌃ + 4 | Scroll half a page down |
| ⌃ + 5 | Scroll half a page up |
| ⌃ + 6 | Scroll a full page down |
| ⌃ + 7 | Scroll a full page up |
| ⌃ + 8 | Scroll to the bottom |
| ⌃ + 9 | scroll to the top |
| ⌃ + 0 | move cursor near right center of window |
| ⌃ + - |  |
| ⌃ + = |  |
| ⌃ + [ |  |
| ⌃ + ] |  |
| ⌃ + ; |  |
| ⌃ + ‘ |  |
| ⌃ + , |  |
| ⌃ + . |  |
| ⌃ + / |  |