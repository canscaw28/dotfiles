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
   | T | Aerospace | Window management and workspace switching |

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
   | Aerospace (T) | 4 (number row) | Join | Join windows directionally |
   | Aerospace (T) | E (middle) | Move to WS | Move window to workspace (stay) |
   | Aerospace (T) | R+E (ring+middle) | Move+Follow | Move window to workspace and follow |
   | Aerospace (T) | W+E | Focus Mon 1 | Focus workspace on monitor 1 |
   | Aerospace (T) | W+R | Focus Mon 2 | Focus workspace on monitor 2 |
   | Aerospace (T) | W+3 | Focus Mon 3 | Focus workspace on monitor 3 |
   | Aerospace (T) | W+4 | Focus Mon 4 | Focus workspace on monitor 4 |

   Notice that S and D are not separate layers — they are **modes of the Default layer**. The pointer finger is absent (no layer key held), so the middle and ring fingers are free to select a mode on the home row. Similarly, F is not a mode of Chrome — it's a mode key for the G layer, pressed by the middle finger while the pointer holds G.

   Mode keys are always relative to the pointer finger's position:
   - **Default layer** (pointer absent): modes use home-row neighbors **S**, **D**
   - **G layer** (pointer on G): modes use **F**, and potentially **D**, **V**, **B**
   - **T layer** (pointer on T): modes use **R**, **E**, **W**, **3**, **4**

   This means learning a new layer doesn't require memorizing arbitrary modifier keys — the mode keys are always "the fingers next to the layer key."

   **Order-independent**: Mode key setters activate on `caps_lock_is_held` alone (not `caps + layer_key`), so keys can be pressed in any order. For example, `⇪ + W + R + T + m` works identically whether you press T before W and R or after — as long as all keys are held simultaneously when the workspace key is pressed.

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
| Aerospace | Join (4+T) | join ← / → | | |

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
| | ⇪ + T | 4 | Join | Join windows directionally |
| | ⇪ + T | E | Move to WS | Move window to workspace (stay) |
| | ⇪ + T | R+E | Move+Follow | Move window to workspace and follow |
| | ⇪ + T | W+E | Focus Mon 1 | Focus workspace on monitor 1 |
| | ⇪ + T | W+R | Focus Mon 2 | Focus workspace on monitor 2 |
| | ⇪ + T | W+3 | Focus Mon 3 | Focus workspace on monitor 3 |
| | ⇪ + T | W+4 | Focus Mon 4 | Focus workspace on monitor 4 |
| System | ⇪ + A | — | System Toggles | Dock, Notification Center, Mission Control, etc. |
| *(unassigned)* | ⇪ + R | | | |

*Available layer keys: R, Z, X, C, V, B*

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
| ⇪ + F + N |  |  |
| ⇪ + F + M |  |  |
| ⇪ + F + , |  |  |
| ⇪ + F + . |  |  |
| ⇪ + F + / |  |  |

### Cursor Grid Movement — ⇪ + F + D (8×8) / ⇪ + F + S (32×32)

Moves the mouse cursor within the focused window on a grid. D mode uses an 8×8 grid for coarse positioning, S mode uses 32×32 for fine precision. On first keypress, snaps to the nearest grid cell from the current mouse position. An amber indicator flashes at the cursor position after each move.

| Key | Action |
| --- | --- |
| ⇪ + F + D/S + H | Move cursor 1 grid cell left |
| ⇪ + F + D/S + J | Move cursor 1 grid cell down |
| ⇪ + F + D/S + K | Move cursor 1 grid cell up |
| ⇪ + F + D/S + L | Move cursor 1 grid cell right |
| ⇪ + F + D/S + Y | Jump to left edge |
| ⇪ + F + D/S + O | Jump to right edge |
| ⇪ + F + D/S + U | Move cursor 2 grid cells left |
| ⇪ + F + D/S + I | Move cursor 2 grid cells right |
| ⇪ + F + D/S + N | Jump to bottom edge |
| ⇪ + F + D/S + . | Jump to top edge |
| ⇪ + F + D/S + M | Move cursor 2 grid cells down |
| ⇪ + F + D/S + , | Move cursor 2 grid cells up |

### Cursor Fixed Positions — ⇪ + F + E

Jumps the mouse cursor to fixed positions within the focused window. An amber indicator flashes at the target position.

| Key | Position |
| --- | --- |
| ⇪ + F + E + H | Left edge, center height |
| ⇪ + F + E + L | Right edge, center height |
| ⇪ + F + E + J | Bottom edge, center width |
| ⇪ + F + E + K | Top edge, center width |
| ⇪ + F + E + ; | Window center |
| ⇪ + F + E + Y | Top-left corner |
| ⇪ + F + E + O | Top-right corner |
| ⇪ + F + E + N | Bottom-left corner |
| ⇪ + F + E + . | Bottom-right corner |
| ⇪ + F + E + U | Top-left quadrant center |
| ⇪ + F + E + I | Top-right quadrant center |
| ⇪ + F + E + M | Bottom-left quadrant center |
| ⇪ + F + E + , | Bottom-right quadrant center |

### Grid Overlay — ⇪ + F + D/S/E + P

Toggles a grid overlay on the focused window. Shows an 8×8 grid in D/E modes, and a hierarchical 32×32 grid in S mode with color-coded line density (green = 2×2 major, light blue = 8×8, dashed = 16×16).

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
| ⇪ + T + ; | *available* | |
| ⇪ + T + ' | ⌘ + ⌥ + ⌃ + ' | Switch to previous workspace (back-and-forth) |
| ⇪ + T + - | ⌘ + ⌥ + ⌃ + ⇧ + - | Resize smart -50 |
| ⇪ + T + = | ⌘ + ⌥ + ⌃ + ⇧ + = | Resize smart +50 |
| ⇪ + T + / | ⌘ + ⌥ + ⇧ + / | Toggle tiles horizontal/vertical |
| ⇪ + T + . | ⌘ + ⌥ + ⇧ + . | Toggle accordion horizontal/vertical |
| ⇪ + T + , | ⌘ + ⌥ + ⇧ + , | Balance window sizes |
| ⇪ + T + N | ⌘ + ⌥ + ⇧ + N | Toggle floating/tiling |
| ⇪ + T + M | ⌘ + ⌥ + ⇧ + M | Flatten workspace tree |
| ⇪ + T + P | *available* | |
| ⇪ + T + Y | *available* | |
| ⇪ + T + U | *available* | |
| ⇪ + T + I | *available* | |
| ⇪ + T + O | *available* | |

### Move Mode (⇪ + R + T)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + R + T + H | ⌘ + ⌥ + ⌃ + Y | Move window left (crosses to adjacent monitor at edge) |
| ⇪ + R + T + J | ⌘ + ⌥ + ⌃ + U | Move window down (crosses to adjacent monitor at edge) |
| ⇪ + R + T + K | ⌘ + ⌥ + ⌃ + I | Move window up (crosses to adjacent monitor at edge) |
| ⇪ + R + T + L | ⌘ + ⌥ + ⌃ + O | Move window right (crosses to adjacent monitor at edge) |
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

### Join Mode (⇪ + 4 + T)

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + 4 + T + H | ⌘ + ⌥ + ⌃ + N | Join with left |
| ⇪ + 4 + T + J | ⌘ + ⌥ + ⌃ + M | Join with down |
| ⇪ + 4 + T + K | ⌘ + ⌥ + ⌃ + , | Join with up |
| ⇪ + 4 + T + L | ⌘ + ⌥ + ⌃ + . | Join with right |
| ⇪ + 4 + T + Y | *available* | |
| ⇪ + 4 + T + U | *available* | |
| ⇪ + 4 + T + I | *available* | |
| ⇪ + 4 + T + O | *available* | |
| ⇪ + 4 + T + P | *available* | |
| ⇪ + 4 + T + ; | *available* | |
| ⇪ + 4 + T + ' | *available* | |
| ⇪ + 4 + T + N | *available* | |
| ⇪ + 4 + T + M | *available* | |
| ⇪ + 4 + T + , | *available* | |
| ⇪ + 4 + T + . | *available* | |
| ⇪ + 4 + T + / | *available* | |

### Workspace Operations

All workspace operations execute directly via Karabiner `shell_command` (calling `ws.sh`), bypassing AeroSpace keybindings entirely. This avoids modifier conflicts with app shortcuts like `Cmd+Shift+H`.

20 workspaces mapped to a right-hand grid:

```
6  7  8  9  0
y  u  i  o  p
h  j  k  l  ;
n  m  ,  .  /
```

### Move to Workspace (⇪ + E + T)

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + E + T + *key* | Move focused window to workspace (stay on current) |

### Move + Follow to Workspace (⇪ + R + E + T)

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + R + E + T + *key* | Move window to workspace and follow on current monitor |

### Focus Monitor 1 (⇪ + W + E + T)

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + W + E + T + *key* | Focus workspace on monitor 1 |

### Focus Monitor 2 (⇪ + W + R + T)

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + W + R + T + *key* | Focus workspace on monitor 2 (falls back to monitor 1) |

### Focus Monitor 3 (⇪ + W + 3 + T)

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + W + 3 + T + *key* | Focus workspace on monitor 3 (falls back to monitor 1) |

### Focus Monitor 4 (⇪ + W + 4 + T)

| Key / Shortcut | Description |
| --- | --- |
| ⇪ + W + 4 + T + *key* | Focus workspace on monitor 4 (falls back to monitor 1) |

### Swap Implementation

Swap operations use `summon-workspace` with an empty buffer workspace (`~`) to avoid visual jitter. AeroSpace's `move-workspace-to-monitor` internally refocuses the moved workspace, causing random workspaces to flash on the source monitor. The summon-based approach only shows `~` (empty) as an intermediate state.

The `on-focus-changed` callback is deliberately disabled in `.aerospace.toml` — it fires on every intermediate focus change during swaps, causing AeroSpace to drop commands. Instead, `move-mouse window-lazy-center` is called explicitly at the end of each operation in `ws.sh`, `smart-focus.sh`, and `smart-move.sh`.

A shared PID-based lock (`/tmp/aerospace-lock.pid`) prevents concurrent aerospace script execution. Stale locks from killed processes are automatically cleaned up.

### Window State Preservation

Window-to-workspace assignments are automatically saved after every workspace operation. On AeroSpace restart, windows are restored to their previous workspaces by matching on app name and window title.

---

## System Layer (⇪ + A)

macOS system toggles and input source management. Unlike other layers, A does not follow the right-hand directional layout — these are standalone utility shortcuts.

### System Toggles

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + A + Y | Toggle Dock | Shows/hides the macOS Dock on the focused monitor. Uses AeroSpace `freeze-tiling` to prevent window resizing. Auto-hides when changing window focus or switching workspaces. |
| ⇪ + A + U | Toggle Notification Center | Opens/closes the Notification Center via AppleScript |
| ⇪ + A + I | Mission Control | Shows Mission Control |
| ⇪ + A + O | Show Desktop | Shows the desktop (fn+F11) |
| ⇪ + A + M | Toggle Sidecar | Toggles iPad Sidecar display |
| ⇪ + A + / | Clean Dock | Removes recent apps from Dock |

### Input Source

| Key / Shortcut | Behavior | Description |
| --- | --- | --- |
| ⇪ + A + H | English (U.S.) | Switch to English input source |
| ⇪ + A + N | Toggle Input | Toggle between input sources (⌃+Space) |

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