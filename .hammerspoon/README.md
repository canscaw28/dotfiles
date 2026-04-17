# Hammerspoon Configuration

Automation scripts that extend Karabiner and AeroSpace with visual feedback, smooth scrolling, cursor control, and workspace management UI.

## Modules

### Scrolling (`init.lua`)

Vim-style smooth scrolling activated by **Ctrl+Shift** held:

| Key | Action |
|-----|--------|
| J / K | Scroll down / up (continuous, 10px/tick) |
| H / L | Scroll left / right (continuous) |
| U / I | Half-page up / down (animated) |
| Y / O | Jump to top / bottom (animated, 0.3s easing) |

Also runs `cleanup-ws.sh` on display configuration changes (e.g. monitor connect/disconnect).

---

### Workspace Grid (`ws_grid.lua`)

A 4x5 keyboard-staggered overlay showing all 20 workspaces as 3D keycaps, colored by which monitor they're visible on:

| Monitor | Color |
|---------|-------|
| 1 | Blue |
| 2 | Orange |
| 3 | Green |
| 4 | Purple |

The grid follows physical keyboard stagger (each row offset +0.25 cell widths):

```
6  7  8  9  0
 Y  U  I  O  P
  H  J  K  L  ;
   N  M  ,  .  /
```

Each keycap shows:
- Workspace name (bold if active on a monitor)
- `*` prefix on the focused workspace
- Window count as dots (up to 5; shows "5+" for more)
- Row-wide opaque plate backgrounds

**Shown during:** T+W (focus), T+E (move), T+3 (swap), T+W+4 (nav mode)

**Nav mode** (T+W+4): A blue cursor appears on the grid. HJKL moves the cursor across the 4x5 layout. On release, `ws.sh focus` runs on the selected workspace.

**Animation:** Grid slides down 20px with fade on dismiss. Repositions instantly when switching between target monitors.

Workspace state is queried asynchronously via `hs.task.new()` to avoid blocking the main thread.

---

### Workspace Notifications (`ws_notify.lua`)

Animated toast that appears on workspace changes showing the operation performed:

| Scenario | Display |
|----------|---------|
| Focus from different workspace | `*source -> target` |
| Move window (stay on current) | `source -> *target` |
| Focus current workspace | `*workspace` |

- Sized to content (min 56x56px), centered on target monitor
- Border color matches monitor (same blue/orange/green/purple scheme)
- Up to 4 toasts stack vertically; older toasts gray out and fall off
- Rise-hold-fall animation: holds 0.7s, then falls 20px while fading

---

### Focus Border (`focus_border.lua`)

Amber rounded-rectangle border that flashes around the focused window after keyboard-driven focus changes. Never fires on mouse clicks.

- Color: orange-amber `rgb(255, 153, 26)` at 80% opacity
- Corner radius: 12px, stroke width: 6px
- 50ms delay before drawing (waits for AeroSpace focus to settle)
- Holds 0.25s, then fades out over 8 steps

Called from `ws.sh`, `smart-focus.sh`, `smart-move.sh`, and AeroSpace keybindings via the HTTP server.

---

### Cursor Grid (`cursor_grid.lua`)

Grid-based mouse cursor positioning within the focused window, activated through the F layer:

**F+D — Coarse grid (8x8)**

| Key | Action |
|-----|--------|
| H / L | Move 1 cell left / right |
| J / K | Move 1 cell down / up |
| U / I | Move 2 cells left / right |
| M / , | Move 2 cells down / up |
| Y / O | Jump to left / right edge |
| N / . | Jump to bottom / top edge |

**F+S — Fine grid (32x32)**

Same keys as F+D but on a 32x32 grid for sub-pixel precision.

**F+E — Fixed positions (jump)**

| Key | Position |
|-----|----------|
| H / L | Left / right edge center |
| J / K | Bottom / top edge center |
| ; | Window center |
| Y / O / N / . | Corners (TL / TR / BL / BR) |
| U / I / M / , | Quadrant centers (TL / TR / BL / BR) |

**F+D/S/E+P — Grid overlay toggle**

Shows a visual grid on the focused window. D/E modes show 8x8; S mode shows hierarchical 32x32 with color-coded line density (green major, light blue mid, purple dashed minor).

An amber indicator dot flashes at the cursor position after each move. Hold-to-repeat supported (0.3s delay, 65ms interval).

---

### Line Navigation (`line_nav.lua`)

Solves a problem with web editors (Notion, Google Docs) where `Cmd+Left/Right` jumps to the end of an entire paragraph instead of the visual line.

Karabiner sends F-keys via `to_if_held_down`; Hammerspoon intercepts them and sends a compound action (arrow + snap) with proper timing:

| Shortcut | F-Key | Action |
|----------|-------|--------|
| Caps+Y | F13 | Up, then Cmd+Left (start of visual line) |
| Caps+O | F14 | Down, then Cmd+Right (end of visual line) |
| Caps+S+Y | F17 | Shift+Up, then Cmd+Shift+Left (select to line start) |
| Caps+S+O | F20 | Shift+Down, then Cmd+Shift+Right (select to line end) |
| Caps+D+Y | F6 | Shift+Up, then Delete (delete visual line up) |
| Caps+D+O | F5 | Shift+Down, then ForwardDelete (delete visual line down) |

Arrow fires immediately; snap follows 20ms later (allowing the app to reflow). Delete operations fire both immediately (no visible selection flash). Hold-to-repeat at 83ms interval.

---

### Chrome Tab Switching (`chrome_tabs.lua`)

Keyboard-driven tab switching with hold-to-repeat and cross-window wrapping:

- Switches tabs via JXA (JavaScript for Automation) for reliability
- On hold: 0.2s initial delay, then 70ms repeat interval
- When reaching the last/first tab, wraps to the next/previous Chrome window (via AeroSpace focus) and lands on the near-edge tab
- 150ms settle delay after cross-window focus before landing

### Chrome JXA Warmup (`chrome_warmup.lua`)

Pre-warms Chrome's Apple Events ScriptingBridge on Hammerspoon startup and on Chrome launch (2s delay). Eliminates the multi-second cold start on first tab switch.

### Chrome Window Focus (`chrome_focus.lua`)

Directional focus navigation across Chrome windows (left/right/up/down). Finds the nearest Chrome window in the specified direction by center-point distance. Flashes focus border on the target.

### Chrome Tab Move (`chrome_tab_move.lua`)

Positions newly created Chrome windows (from the tab-mover extension) into the correct workspace grid position. Called via HTTP from the Chrome extension when splitting a tab to a new window.

---

### Dock Management (`dock_peek.lua`, `dock_focus.lua`)

**dock_peek** — Show/hide the macOS Dock with AeroSpace integration:

1. **Show**: Freezes AeroSpace tiling (prevents window resizing), warps cursor to dock edge so macOS shows it on the correct monitor, then restores cursor position
2. **Hide**: Hides dock, waits 0.3s, then unfreezes tiling

**dock_focus** — Virtual window focus while dock is visible. Arrow keys highlight windows with the focus border but don't actually change focus (which would dismiss the dock). Real focus is applied when the dock hides.

---

### Input Source (`input_source.lua`)

Save and restore keyboard input source. Used to temporarily switch to English for operations that require it, then restore the previous layout.

### Show Desktop (`show_desktop.lua`)

State tracker for macOS Show Desktop mode (triggered by Caps+A+O → fn+F11). Tracks toggle state so other modules can dismiss it programmatically.

### Key Suppress (`key_suppress.lua`)

Eventtap that suppresses OS key auto-repeat for all keys while any Caps Lock layer is active. Started by Karabiner's caps-lock setters, stopped on caps release. This allows Hammerspoon and Karabiner to handle repeat behavior themselves.

### Raycast Watcher (`raycast_watcher.lua`)

Mirrors Raycast's command-bar visibility into the `raycast_active` Karabiner variable. Raycast's panel is a nonactivating `NSPanel`, so it doesn't change the frontmost app — which means Karabiner's `frontmost_application_if` conditions would otherwise still apply iTerm2 (or other app) overrides to keys typed into Raycast.

Uses `hs.window.filter` scoped to Raycast with `allowRoles = "*"` to catch the panel window. Sets `raycast_active=1` on `windowCreated`/`windowVisible`, `0` on `windowDestroyed`/`windowNotVisible`, and resets to `0` on module load for safety.

Consumed in `karabiner/src/layers/default.yaml` via `always_negative: [raycast_active]` on every iTerm-scoped section, so those overrides disable when Raycast is open.

---

### HTTP Server (`hs_server.lua`)

Local HTTP server on port 27183 for IPC from shell scripts and browser extensions:

| Endpoint | Effect |
|----------|--------|
| `/focus-border-flash` | Flash focus border on focused window |
| `/chrome-tab-new-window?direction=...&follow=...` | Position new Chrome window from tab-mover extension |

Used by `ws.sh`, `smart-focus.sh`, `smart-move.sh`, and the Chrome tab-mover extension.

---

## Integration

Hammerspoon sits between Karabiner and AeroSpace in the input pipeline:

```
Keypress → Karabiner (layer/mode selection, F-key encoding)
         → Hammerspoon (visual feedback, compound actions, async operations)
         → AeroSpace (window/workspace management)
         → Shell scripts (ws.sh, smart-focus.sh, etc.)
         → Hammerspoon HTTP server (focus border, grid updates)
```

Key integration points:
- **Karabiner → Hammerspoon**: F-keys for line nav, modifier-encoded workspace keys for ws_grid, Ctrl+Shift for scrolling
- **Shell → Hammerspoon**: HTTP calls to `localhost:27183` for focus border, `hs` CLI for grid updates
- **Chrome extension → Hammerspoon**: HTTP calls for new window positioning
- **Hammerspoon → AeroSpace**: CLI calls via `hs.task.new()` (never `hs.execute()` — blocks main thread)
