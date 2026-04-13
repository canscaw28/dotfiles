# Karabiner Elements Configuration

Caps Lock becomes a modifier system where the **left hand picks context** and the **right hand picks action**.

## Contents

- [Layers](#layers)
- [Design](#design)
- [Modes](#modes)
- [Misc Shortcuts](#misc-shortcuts)
- [Default Layer (⇪)](#default-layer-)
- [Scroll / Cursor Grid Layer (⇪+F)](#scroll--cursor-grid-layer-f)
- [Application Layer (⇪+G)](#application-layer-g)
- [Aerospace Layer (⇪+T)](#aerospace-layer-t)
- [App Layer (⇪+R)](#app-layer-r)
- [System Layer (⇪+A)](#system-layer-a)
- [MacBook Keyboard Ghosting](#macbook-keyboard-ghosting)

## Layers

| Layer Key | Layer | Domain |
| --- | --- | --- |
| ⇪ | Default | Cursor movement, text selection, deletion |
| ⇪ + F | Scroll / Cursor Grid | Page scrolling, mouse cursor control, link hints |
| ⇪ + G | Application | App-specific behavior (Chrome tabs, iTerm tmux, etc.) |
| ⇪ + T | Aerospace | Window tiling and workspace operations |
| ⇪ + A | System | Dock, Notification Center, input source, etc. |
| ⇪ + R | App-specific | Superhuman split inbox navigation |

## Design

Left hand has three tiers: **pinky** holds Caps Lock, **pointer** selects the layer, **middle/ring** select a mode within that layer. Mode keys sit adjacent to the pointer's layer key, so each layer+mode is a single hand shape. Keys can be pressed in any order — only what's held when the action key fires matters.

Right hand layout is always the same — vim directions that stay consistent across every layer:

```
     Y  U  I  O              ← extreme (boundary jumps)
       H  J  K  L            ← core (←↓↑→)
         N  M  ,  .          ← extensions
```

**Available layer keys:** R, Z, X, C, V, B

## Modes

| Layer | Mode Key | Mode | Description |
| --- | --- | --- | --- |
| Default | — | Cursor | Move the cursor |
| | S | Selection | Select text instead of moving |
| | D | Deletion | Delete text instead of moving |
| Scroll (F) | — | Scroll | Page scrolling via Hammerspoon |
| | D | Coarse Grid | 8x8 mouse cursor grid |
| | S | Fine Grid | 32x32 mouse cursor grid |
| | E | Link Hints / Jump | Fixed cursor positions, Vimium/Homerow hints |
| Application (G) | — | Navigation | App-specific (Chrome: tabs, iTerm: tmux, other: window focus) |
| | F | Reorder | Chrome: reorder tabs within a window |
| | D | Tab Move | Chrome: move tab to another window |
| Aerospace (T) | — | Focus | Window focus management |
| | R | Move | Move windows directionally |
| | 4 | Join | Join windows directionally |
| | W | Focus WS | Focus workspace on current monitor |
| | E | Move to WS | Move window to workspace (stay) |
| | R+E | Move+Follow | Move window to workspace and follow |
| | W+E | Focus Mon 1 | Focus workspace on monitor 1 |
| | W+R | Focus Mon 2 | Focus workspace on monitor 2 |
| | 3 | Swap Windows | Swap all windows between workspaces |
| | W+4 | Nav Grid | HJKL cursor over workspace grid |
| System (A) | — | System Toggles | Dock, Notification Center, Mission Control, etc. |
| App (R) | — | App-specific | Superhuman: navigate split inboxes (Chrome) |

## Misc Shortcuts

| Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + ⇪ | LanguageTool | Double-tap Caps Lock to trigger LanguageTool tooltip |
| ⇪ + R⇧ | ⇪ | Trigger Caps-Lock |

---

## Default Layer (⇪)

### Cursor Movement

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪] + H | ← | Move cursor to the left |
| [⇪] + J | ↓ | Move cursor down |
| [⇪] + K | ↑ | Move cursor up |
| [⇪] + L | →  | Move cursor to the right |
| [⇪] + ; | Esc | Easy to reach Esc key alternative |
| [⇪] + Y | ⌘ + ← | Jumps cursor to the start of the line |
| [⇪] + U | ⌥ + ← | Jump back one word |
| [⇪] + I | ⌥ + → | Jump forward one word |
| [⇪] + O | ⌘ + → | Jumps cursor to the end of the line |
| [⇪] + P |  |  |
| [⇪] + N |  |  |
| [⇪] + M | ⌘ + ↓ | Moves cursor to the bottom of an input field |
| [⇪] + , | ⌘ + ↑ | Moves cursor to the top of an input field |
| [⇪] + . |  |  |
| [⇪] + / |  |  |

### Selection Mode (⇪ + S)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+S] + H | ⇧ + ← | Select text left one character |
| [⇪+S] + J | ⇧ + ↓ | Select text downwards |
| [⇪+S] + K | ⇧ + ↑ | Select text upwards |
| [⇪+S] + L | ⇧ + →  | Select text right one character |
| [⇪+S] + ; | ⌘ + A | Select the entire text field |
| [⇪+S] + Y | ⌘ + ⇧ + ← | Select text to the start of the line |
| [⇪+S] + U | ⌥ + ⇧ + ← | Select the word to the left |
| [⇪+S] + I | ⌥ + ⇧ + → | Select the word to the right |
| [⇪+S] + O | ⌘ + ⇧ + → | Select text to the end of the line |
| [⇪+S] + P | ⌘ + ←, ⌘ + ⇧ + → | Select the entire line |
| [⇪+S] + N |  |  |
| [⇪+S] + M | ⌥ + ⇧ + ↓ | Moves cursor to the bottom of an input field |
| [⇪+S] + , | ⌥ + ⇧ + ↑ | Moves cursor to the top of an input field |
| [⇪+S] + . |  |  |
| [⇪+S] + / |  |  |

### Deletion Mode (⇪ + D)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+D] + H | ⌫ | Delete one character to the left |
| [⇪+D] + J | ⇧ + ↓, ⌫ | Delete the line down from the cursor |
| [⇪+D] + K | ⇧ + ↑, ⌫ | Delete the line up from the cursor |
| [⇪+D] + L | ⌦ | Delete one character to the right |
| [⇪+D] + ; | ⌘ + A, ⌫ | Delete whole text area |
| [⇪+D] + Y | ⌘ + ⌫ | Delete the line to the left |
| [⇪+D] + U | ⌥ + ⌫ | Delete the word to the left |
| [⇪+D] + I | ⌥ + ⌦ | Delete the word to the right |
| [⇪+D] + O | ⌘ + ⇧ + →, ⌫ | Delete the line to the right |
| [⇪+D] + P | ⌘ + →, ⌘ + ⌫ | Delete the whole line |
| [⇪+D] + N |  |  |
| [⇪+D] + M | ⌃ + K | Delete the paragraph down from the cursor |
| [⇪+D] + , | ⌥ + ⇧ + ↑, ⌫ | Delete the paragraph up from the cursor |
| [⇪+D] + . |  |  |
| [⇪+D] + / |  |  |

---

## Scroll / Cursor Grid Layer (⇪+F)

### Scrolling

Karabiner sends ⌃+⇧+key which Hammerspoon's eventtap intercepts to perform smooth scrolling:

| Key / Shortcut | Action | Description |
| --- | --- | --- |
| [⇪+F] + H | Scroll left | Continuous scroll left |
| [⇪+F] + J | Scroll down | Continuous scroll down |
| [⇪+F] + K | Scroll up | Continuous scroll up |
| [⇪+F] + L | Scroll right | Continuous scroll right |
| [⇪+F] + Y | Scroll to top | Jump to top (animated, 0.3s) |
| [⇪+F] + O | Scroll to bottom | Jump to bottom (animated, 0.3s) |
| [⇪+F] + U | Half-page up | Smooth half-page scroll up |
| [⇪+F] + I | Half-page down | Smooth half-page scroll down |
| [⇪+F] + ; | Left click | Click at current cursor position |
| [⇪+F] + ' | Right click | Right-click at current cursor position |
| [⇪+F] + N |  |  |
| [⇪+F] + M |  |  |
| [⇪+F] + , |  |  |
| [⇪+F] + . |  |  |
| [⇪+F] + / |  |  |
| [⇪+F] + P | Toggle grid | Toggle grid overlay on focused window |

### Coarse Cursor Grid (⇪+F + D) — 8×8

Moves the mouse cursor within the focused window on an 8×8 grid. On first keypress, snaps to the nearest grid cell from the current mouse position. An amber indicator flashes at the cursor position after each move.

| Key | Action |
| --- | --- |
| [⇪+F+D] + H | Move cursor 1 grid cell left |
| [⇪+F+D] + J | Move cursor 1 grid cell down |
| [⇪+F+D] + K | Move cursor 1 grid cell up |
| [⇪+F+D] + L | Move cursor 1 grid cell right |
| [⇪+F+D] + Y | Jump to left edge |
| [⇪+F+D] + O | Jump to right edge |
| [⇪+F+D] + U | Move cursor 2 grid cells left |
| [⇪+F+D] + I | Move cursor 2 grid cells right |
| [⇪+F+D] + N | Jump to bottom edge |
| [⇪+F+D] + . | Jump to top edge |
| [⇪+F+D] + M | Move cursor 2 grid cells down |
| [⇪+F+D] + , | Move cursor 2 grid cells up |

### Fine Cursor Grid (⇪+F + S) — 32×32

Same keys as the coarse grid but on a 32×32 grid for fine precision.

| Key | Action |
| --- | --- |
| [⇪+F+S] + H | Move cursor 1 grid cell left |
| [⇪+F+S] + J | Move cursor 1 grid cell down |
| [⇪+F+S] + K | Move cursor 1 grid cell up |
| [⇪+F+S] + L | Move cursor 1 grid cell right |
| [⇪+F+S] + Y | Jump to left edge |
| [⇪+F+S] + O | Jump to right edge |
| [⇪+F+S] + U | Move cursor 2 grid cells left |
| [⇪+F+S] + I | Move cursor 2 grid cells right |
| [⇪+F+S] + N | Jump to bottom edge |
| [⇪+F+S] + . | Jump to top edge |
| [⇪+F+S] + M | Move cursor 2 grid cells down |
| [⇪+F+S] + , | Move cursor 2 grid cells up |

### Cursor Fixed Positions — ⇪ + F + E

Jumps the mouse cursor to fixed positions within the focused window. An amber indicator flashes at the target position.

| Key | Position |
| --- | --- |
| [⇪+F+E] + H | Left edge, center height |
| [⇪+F+E] + L | Right edge, center height |
| [⇪+F+E] + J | Bottom edge, center width |
| [⇪+F+E] + K | Top edge, center width |
| [⇪+F+E] + ; | Window center |
| [⇪+F+E] + Y | Top-left corner |
| [⇪+F+E] + O | Top-right corner |
| [⇪+F+E] + N | Bottom-left corner |
| [⇪+F+E] + . | Bottom-right corner |
| [⇪+F+E] + U | Top-left quadrant center |
| [⇪+F+E] + I | Top-right quadrant center |
| [⇪+F+E] + M | Bottom-left quadrant center |
| [⇪+F+E] + , | Bottom-right quadrant center |

### Link Hints (⇪+F + E, Chrome/Homerow)

In Chrome, F+E also provides Vimium and Homerow integration:

| Key | Action |
| --- | --- |
| [⇪+F+E] + J | Vimium link hints (Chrome) |
| [⇪+F+E] + K | Vimium hover hints (Chrome) |
| [⇪+F+E] + ; | Toggle Vimium (Chrome) |
| [⇪+F+E] + H | Homerow scroll mode |

### Grid Overlay (⇪+F + D/S/E + P)

Toggles a grid overlay on the focused window. Shows an 8×8 grid in D/E modes, and a hierarchical 32×32 grid in S mode with color-coded line density (green = 2×2 major, light blue = 8×8, dashed = 16×16).

---

## Application Layer (⇪+G)

The G layer provides app-specific behavior. In Chrome it controls tabs and windows, in iTerm2 it controls tmux panes, and in other apps it provides generic directional window focus.

### Chrome

#### Tab Navigation

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+G] + H | Prev tab | Previous tab (wraps to previous window at boundary) |
| [⇪+G] + L | Next tab | Next tab (wraps to next window at boundary) |
| [⇪+G] + Y | First tab | First tab in current window |
| [⇪+G] + O | Last tab | Last tab in current window |
| [⇪+G] + U | Jump 3 left | Jump 3 tabs to the left |
| [⇪+G] + I | Jump 3 right | Jump 3 tabs to the right |
| [⇪+G] + J | Focus window ↓ | Focus nearest Chrome window below |
| [⇪+G] + K | Focus window ↑ | Focus nearest Chrome window above |
| [⇪+G] + ; | Esc; T | Trigger Vimium Tab search |
| [⇪+G] + ' | Esc; o | Trigger Vimium history search |
| [⇪+G] + P | ⌃ + G | Toggle Gemini side panel |
| [⇪+G] + [ | ⌘ + [ | Navigate back in history |
| [⇪+G] + ] | ⌘ + ] | Navigate forward in history |
| [⇪+G] + N | ⌘ + T | New tab |
| [⇪+G] + M | Duplicate tab | Duplicate current tab |
| [⇪+G] + , | ⌘ + ⇧ + T | Reopen last closed tab |
| [⇪+G] + . | ⌘ + W | Close current tab |
| [⇪+G] + / | Detach tab | Detach tab to new window |

Tab switching (H/L/Y/O/U/I) uses Hammerspoon JXA for reliability, with hold-to-repeat (0.2s delay, 70ms interval) and cross-window wrapping via AeroSpace.

#### Tab Reorder Mode (⇪+F+G)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+F+G] + H | Esc; << | Move tab one position to the left |
| [⇪+F+G] + L | Esc; >> | Move tab one position to the right |
| [⇪+F+G] + Y | Esc; 100<< | Move tab to the beginning |
| [⇪+F+G] + O | Esc; 100>> | Move tab to the end |
| [⇪+F+G] + U | Esc; 3<< | Move tab 3 positions to the left |
| [⇪+F+G] + I | Esc; 3>> | Move tab 3 positions to the right |
| [⇪+F+G] + J | Move tab + focus ↓ | Move tab to window below and follow |
| [⇪+F+G] + K | Move tab + focus ↑ | Move tab to window above and follow |

#### Tab Move Mode (⇪+D+G)

Moves the current tab to another Chrome window in the specified direction, using the tab-mover Chrome extension:

| Key / Shortcut | Description |
| --- | --- |
| [⇪+D+G] + H | Move tab to Chrome window on the left |
| [⇪+D+G] + J | Move tab to Chrome window below |
| [⇪+D+G] + K | Move tab to Chrome window above |
| [⇪+D+G] + L | Move tab to Chrome window on the right |

### iTerm2

When iTerm2 is frontmost, several default layer keys are overridden with terminal-compatible sequences, and the G layer switches to tmux pane navigation.

#### Cursor Movement

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪] + Y | ⌃ + A | Jump to start of line |
| [⇪] + U | ⌥ + ← | Jump back one word |
| [⇪] + I | ⌥ + → | Jump forward one word |
| [⇪] + O | ⌃ + E | Jump to end of line |

*⇪+J/K use smart navigation: on single-line commands they navigate history with prefix search. On multi-line commands they move the cursor, with double-tap at boundaries to switch to history navigation.*

#### History Navigation

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪] + , | ⌃ + P | Search history backward with prefix matching |
| [⇪] + M | ⌃ + N | Search history forward with prefix matching |

*Type a partial command, then use these keys to find matching history entries (e.g., type "git" then ⇪+, to find commands starting with "git").*

#### Text Deletion

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+D] + Y | ⌃ + U | Delete from cursor to start of line |
| [⇪+D] + U | ⌃ + W | Delete word to the left |
| [⇪+D] + I | ⌥ + D | Delete word to the right |
| [⇪+D] + O | ⌃ + K | Delete from cursor to end of line |
| [⇪+D] + J | F18 | Delete to line below |
| [⇪+D] + K | F19 | Delete to line above |

#### Undo/Redo

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⌘ + Z | ⌃ + _ | Undo last text change |
| ⌘ + ⇧ + Z | Esc + _ | Redo last undo |

#### Text Selection

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+S] + H | ⇧ + ← | Select character to the left |
| [⇪+S] + J | ⌃ + ⇧ + ↓ | Select line down (to end of buffer on last line) |
| [⇪+S] + K | ⌃ + ⇧ + ↑ | Select line up (to start of buffer on first line) |
| [⇪+S] + L | ⇧ + → | Select character to the right |
| [⇪+S] + Y | ⇧ + Home | Select to start of line |
| [⇪+S] + U | ⌃ + ⇧ + ← | Select word to the left |
| [⇪+S] + I | ⌃ + ⇧ + → | Select word to the right |
| [⇪+S] + O | ⇧ + End | Select to end of line |
| [⇪+S] + ; | ⌥ + A | Select entire command buffer |

#### Standard Commands

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⌘ + A | ⌥ + A | Select entire command buffer (not terminal output) |
| ⌘ + C | ⌥ + C | Copy selection if active, else Ctrl+C interrupt |

#### Clipboard Operations

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+⌘] + C | F15 | Copy selection to system clipboard |
| [⇪+⌘] + X | F16 | Cut selection to system clipboard |

#### G Layer — Tmux Pane Navigation

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+G] + H | ⌃ + B, ← | Select tmux pane left |
| [⇪+G] + J | ⌃ + B, ↓ | Select tmux pane down |
| [⇪+G] + K | ⌃ + B, ↑ | Select tmux pane up |
| [⇪+G] + L | ⌃ + B, → | Select tmux pane right |
| [⇪+G] + Y | Edge pane left | Jump to leftmost tmux pane |
| [⇪+G] + O | Edge pane right | Jump to rightmost tmux pane |

### Other Apps

| Key / Shortcut | Description |
| --- | --- |
| [⇪+G] + H | Focus window left |
| [⇪+G] + J | Focus window down |
| [⇪+G] + K | Focus window up |
| [⇪+G] + L | Focus window right |

---

## Aerospace Layer (⇪+T)

### Focus

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+T] + H | ⌘ + ⌥ + ⌃ + H | Focus left  |
| [⇪+T] + J | ⌘ + ⌥ + ⌃ + J | Focus down |
| [⇪+T] + K | ⌘ + ⌥ + ⌃ + K | Focus up |
| [⇪+T] + L | ⌘ + ⌥ + ⌃ + L | Focus right |
| [⇪+T] + ; | *available* | |
| [⇪+T] + ' | ⌘ + ⌥ + ⌃ + ' | Switch to previous workspace (back-and-forth) |
| [⇪+T] + - | ⌘ + ⌥ + ⌃ + ⇧ + - | Resize smart -50 |
| [⇪+T] + = | ⌘ + ⌥ + ⌃ + ⇧ + = | Resize smart +50 |
| [⇪+T] + / | ⌘ + ⌥ + ⇧ + / | Toggle tiles horizontal/vertical |
| [⇪+T] + . | ⌘ + ⌥ + ⇧ + . | Toggle accordion horizontal/vertical |
| [⇪+T] + , | ⌘ + ⌥ + ⇧ + , | Toggle floating/tiling |
| [⇪+T] + N | ⌘ + ⌥ + ⇧ + N | Balance window sizes |
| [⇪+T] + M | ⌘ + ⌥ + ⇧ + M | Flatten workspace tree |
| [⇪+T] + P | *available* | |
| [⇪+T] + Y | *available* | |
| [⇪+T] + U | *available* | |
| [⇪+T] + I | *available* | |
| [⇪+T] + O | *available* | |

### Move Mode (⇪+T + R)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+T+R] + H | ⌘ + ⌥ + ⌃ + Y | Move window left (crosses to adjacent monitor at edge) |
| [⇪+T+R] + J | ⌘ + ⌥ + ⌃ + U | Move window down (crosses to adjacent monitor at edge) |
| [⇪+T+R] + K | ⌘ + ⌥ + ⌃ + I | Move window up (crosses to adjacent monitor at edge) |
| [⇪+T+R] + L | ⌘ + ⌥ + ⌃ + O | Move window right (crosses to adjacent monitor at edge) |
| [⇪+T+R] + ' | `ws.sh move-monitor-focus` | Move window to next monitor and follow |

### Join Mode (⇪+T + 4)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+T+4] + H | ⌘ + ⌥ + ⌃ + N | Join with left |
| [⇪+T+4] + J | ⌘ + ⌥ + ⌃ + M | Join with down |
| [⇪+T+4] + K | ⌘ + ⌥ + ⌃ + , | Join with up |
| [⇪+T+4] + L | ⌘ + ⌥ + ⌃ + . | Join with right |

### Workspace Operations

All workspace operations execute directly via Karabiner `shell_command` (calling `ws.sh`), bypassing AeroSpace keybindings entirely. This avoids modifier conflicts with app shortcuts like `Cmd+Shift+H`.

20 workspaces mapped to a right-hand grid:

```
6  7  8  9  0
y  u  i  o  p
h  j  k  l  ;
n  m  ,  .  /
```

### Focus Workspace (⇪+T + W)

| Key / Shortcut | Description |
| --- | --- |
| [⇪+T+W] + *key* | Focus workspace on current monitor (swaps if visible on another) |

### Move to Workspace (⇪+T + E)

| Key / Shortcut | Description |
| --- | --- |
| [⇪+T+E] + *key* | Move focused window to workspace (stay on current) |
| [⇪+T+E] + ' | Move focused window to next monitor (stay on current) |

### Move + Follow to Workspace (⇪+T + R + E)

| Key / Shortcut | Description |
| --- | --- |
| [⇪+T+R+E] + *key* | Move window to workspace and follow on current monitor |
| [⇪+T+R+E] + ' | Move window to next monitor and yank that workspace back |

### Focus Monitor 1 (⇪+T + W + E)

| Key / Shortcut | Description |
| --- | --- |
| [⇪+T+W+E] + *key* | Focus workspace on monitor 1 |

### Focus Monitor 2 (⇪+T + W + R)

| Key / Shortcut | Description |
| --- | --- |
| [⇪+T+W+R] + *key* | Focus workspace on monitor 2 (falls back to monitor 1) |

### Swap Windows (⇪+T + 3)

| Key / Shortcut | Description |
| --- | --- |
| [⇪+T+3] + *key* | Swap all windows between focused workspace and target workspace |
| [⇪+T+3] + ' | Swap workspaces between current and next monitor |

### Nav Grid (⇪+T + W + 4)

Activates a navigation cursor on the workspace grid overlay. Use HJKL to move the cursor across the 4x5 grid. When exiting the mode (releasing keys), `ws.sh focus` runs on the selected workspace.

### Swap Implementation

Swap operations use `summon-workspace` with an empty buffer workspace (`~`) to avoid visual jitter. AeroSpace's `move-workspace-to-monitor` internally refocuses the moved workspace, causing random workspaces to flash on the source monitor. The summon-based approach only shows `~` (empty) as an intermediate state.

The `on-focus-changed` callback is deliberately disabled in `.aerospace.toml` — it fires on every intermediate focus change during swaps, causing AeroSpace to drop commands. Instead, `move-mouse window-lazy-center` is called explicitly at the end of each operation in `ws.sh`, `smart-focus.sh`, and `smart-move.sh`.

A shared PID-based lock (`/tmp/aerospace-lock.pid`) prevents concurrent aerospace script execution. Stale locks from killed processes are automatically cleaned up.

### Window State Preservation

Window-to-workspace assignments are automatically saved after every workspace operation. On AeroSpace restart, windows are restored to their previous workspaces by matching on app name and window title.

---

## App Layer (⇪+R)

App-specific bindings. Currently only Superhuman in Chrome.

### Superhuman Split Inbox (Chrome)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+R] + H | ⇧ + ⇥ | Previous split inbox |
| [⇪+R] + L | ⇥ | Next split inbox |

## System Layer (⇪+A)

macOS system toggles and input source management. Unlike other layers, A does not follow the right-hand directional layout — these are standalone utility shortcuts.

### System Toggles

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+A] + Y | Toggle Dock | Shows/hides the macOS Dock on the focused monitor. Uses AeroSpace `freeze-tiling` to prevent window resizing. Auto-hides when changing window focus or switching workspaces. |
| [⇪+A] + U | Toggle Notification Center | Opens/closes the Notification Center via AppleScript |
| [⇪+A] + I | Mission Control | Shows Mission Control |
| [⇪+A] + O | Show Desktop | Shows the desktop (fn+F11) |
| [⇪+A] + . | Reload All Configs | Runs `reload.sh --all` (AeroSpace, Karabiner, Hammerspoon, iTerm2, Espanso, shell, Chrome) |
| [⇪+A] + M | Toggle Sidecar | Toggles iPad Sidecar display |
| [⇪+A] + / | Clean Dock | Removes recent apps from Dock |
| [⇪+A] + , | Workspace Setup | Opens apps (iTerm2→k, Messages→n, Rize→n, Slack→m) and moves windows to assigned workspaces |

### Input Source

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| [⇪+A] + H | English (U.S.) | Switch to English input source |
| [⇪+A] + N | Toggle Input | Toggle between input sources (⌃+⌥+Space) |

---

## MacBook Keyboard Ghosting

Certain key combinations are silently dropped on the MacBook's built-in keyboard due to the keyboard matrix design. The key event never reaches Karabiner at all. This does not affect external keyboards.

| Keys held | Dropped keys | Impact |
| --- | --- | --- |
| ⇪ + T + Q | U, I, O, P, ; | Q was removed as a workspace mode key because of this |
| ⇪ + A | J, K, L, ; | A layer avoids right-hand home row; uses Y/U/I/O and H/N instead |

Always verify new multi-key combos in Karabiner EventViewer before committing to a binding.

