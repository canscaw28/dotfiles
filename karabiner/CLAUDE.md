# Karabiner Configuration

**NEVER edit `karabiner.json` directly — it is a generated build artifact.**

The source of truth is `src/layers/*.yaml` (6 files, ~6k lines vs the 36k-line generated JSON). One file per layer.

## Workflow

1. Edit the relevant YAML file under `src/layers/`
2. Run `./reload.sh --karabiner` from the repo root (builds via `build.py` then reloads Karabiner)
3. Verify with `python3 build.py --check` (exits 0 if `karabiner.json` matches what would be built from sources)

If you find yourself wanting to edit `karabiner.json` directly, stop and find the corresponding YAML source file.

## File structure

```
karabiner/src/layers/
├── infrastructure.yaml   # Caps lock setup, layer setters, physical trackers
├── a-system.yaml         # A layer (Dock, Notification Center, etc.)
├── default.yaml          # Default layer (cursor, selection, deletion, iTerm overrides)
├── f.yaml                # F layer (scroll, cursor grid, link hints)
├── t.yaml                # T layer (focus/move/join, workspace operations, nav)
└── g.yaml                # G layer (Chrome, iTerm tmux, generic, tab move/reorder)
```

That's it. Six files. `build_order.yaml` controls the ordering.

## Source format

Most files use the **compact format** with `layer:` declaration that auto-infers Karabiner conditions:

```yaml
layer: [caps, g]
negative_conditions: [a, s, d, f, r, t]
app: "^com\\.google\\.Chrome$"

manipulators:
  - from: h
    description: "G+H: Chrome switch tab left"
    to:
      - shell: '/usr/local/bin/hs -c "require(''chrome_tabs'').onKeyDown(-1)" &'
    to_if_held_down: noop
    hold_threshold: 200
```

Files with mixed conditions use the **sections format**:

```yaml
sections:
  - layer: [caps]
    app: "^com\\.googlecode\\.iterm2$"
    manipulators:
      - from: y
        to: [a, control]   # iTerm override

  - layer: [caps]
    manipulators:
      - from: y
        to: [left_arrow, command]   # default behavior
```

Sections are processed in order — earlier sections take first-match priority. For overlapping keys, more-specific (app-conditional) sections must come first.

A few sections use **`raw: true`** with full Karabiner JSON for things that don't fit the standard pattern (caps lock setters, physical trackers).

## Compact format reference

### File-level fields (or section-level)

```yaml
layer: [caps, g]               # Layer keys held; build.py infers conditions
negative_conditions: [a, s, d] # Optional: explicit list of vars to set =0
                               # Default: all layer vars not in `layer` are negated
app: "^com\\.google\\.Chrome$" # Optional: frontmost_application_if condition
app_unless: "^com\\..*"        # Optional: frontmost_application_unless

manipulators:
  - ...
```

### Per-manipulator fields

Each manipulator can override file-level defaults. All fields except `from` are optional.

```yaml
- from: h                        # Trigger key (default modifiers: optional any)
  from_modifiers: [command]      # Optional: mandatory modifiers (Cmd+H)
  description: "G+H: prev tab"   # Optional: shown in karabiner config UI
  layer: [caps, g]               # Optional: override file-level layer
  negative_conditions: [a, s]    # Optional: override file-level negatives
  app: "..."                     # Optional: override file-level app
  conditions: [...]              # Optional: full manual control over conditions
  to: ...                        # Output events (see "to value forms" below)
  to_after_key_up: ...           # Events on key release
  to_if_held_down: noop          # Events when held past threshold
  hold_threshold: 200            # Milliseconds before to_if_held_down fires
  parameters: {...}              # Other Karabiner parameters
```

### `to` value forms

| YAML | Expands to |
|------|-----------|
| `to: left_arrow` | `{key_code: left_arrow}` |
| `to: [h, shift]` | `{key_code: h, modifiers: [shift]}` (single key+mod) |
| `to: [h, command+shift]` | `{key_code: h, modifiers: [command, shift]}` |
| `to: [escape, o]` | Two key events: escape, then o (modifier names rejected) |
| `to: noop` | `{set_variable: {name: guard_noop, value: 0}}` |
| `to: {shell: "cmd"}` | `{shell_command: "cmd"}` |
| `to: {set: {name: 1}}` | `{set_variable: {name: name, value: 1}}` |
| `to: {key: x, modifiers: [...]}` | Full key spec |

For multiple events, use a list:
```yaml
to:
  - [escape, command]    # First: Cmd+Escape
  - {shell: "echo hi"}   # Then: shell command
  - h                    # Then: H
```

### Modifier disambiguation

A two-string list `[a, b]` is interpreted as `[key, modifier]` when `b` looks like a modifier (`shift`, `command`, `option`, `control`, `fn`, or `+`-separated combinations). Otherwise it's two key events.

```yaml
to: [h, shift]      # Shift+H (single event)
to: [escape, o]     # Escape, then O (two events)
```

## Build pipeline

```
src/layers/*.yaml  →  build.py  →  karabiner.json  →  reload Karabiner
```

- `build.py` — assembles YAML sources into the final `karabiner.json`

## Files

| File | Purpose |
|------|---------|
| `karabiner.json` | **Generated** — Karabiner Elements reads this file |
| `build.py` | YAML → JSON builder |
| `src/profile.yaml` | Profile metadata (name, virtual_hid_keyboard, simple_modifications) |
| `src/build_order.yaml` | Controls manipulator priority ordering |
| `src/layers/*.yaml` | Per-layer source files (6 files, one per layer) |
| `README.md` | User-facing documentation of all keyboard shortcuts |
