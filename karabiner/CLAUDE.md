# Karabiner Configuration

**NEVER edit `karabiner.json` directly — it is a generated build artifact.**

The source of truth is `src/layers/*.yaml` (45 files, ~6k lines vs the 36k-line generated JSON).

## Workflow

1. Edit the relevant YAML file under `src/layers/`
2. Run `./reload.sh --karabiner` from the repo root (builds via `build.py` then reloads Karabiner)
3. Verify with `python3 build.py --check` (exits 0 if `karabiner.json` matches what would be built from sources)

If you find yourself wanting to edit `karabiner.json` directly, stop and find the corresponding YAML source file.

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

A few files use **`raw: true`** and contain full Karabiner JSON in YAML form. These are:
- Infrastructure (caps lock setters, re-press handlers)
- Layer setters (S, D, F, R, E, W, etc.)
- Physical key trackers
- Anything with non-standard condition patterns

`raw: true` files should not be converted unless you understand exactly what they do.

## Compact format reference

### File-level fields

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

### Generated files

These files are produced by scripts and should not be edited directly:

| File | Generator script |
|------|-----------------|
| `caps-physical.yaml` | `scripts/apply_physical_trackers.py` |
| `t-ws-actions.yaml` | `scripts/apply_t_ws_layer.py` |
| `t-nav.yaml` | `scripts/apply_t_ws_layer.py` |
| `t-ws-guards.yaml` | `scripts/apply_t_ws_layer.py` |
| `physical-trackers.yaml` | `scripts/apply_physical_trackers.py` |
| `f-cursor-grid.yaml` | `scripts/apply_f_cursor_grid.py` |

To change generated content, edit the generator script and re-run it.

### Build order

`build_order.yaml` controls the order manipulators are assembled into karabiner.json. Karabiner uses first-match priority, so files with more specific conditions (e.g. `frontmost_application_if`) must come BEFORE files with less specific conditions.

Current ordering:
1. Infrastructure (caps lock setup, physical trackers)
2. Layer setters (S, D, F, R, E, etc.)
3. A layer (system toggles)
4. F grid setters
5. G+D Chrome tab move
6. iTerm-specific (non-caps + caps overrides) — must come BEFORE default layer
7. Default layer (cursor, selection, deletion)
8. F layer (link hints, cursor grid, scroll)
9. T layer (workspace actions, nav, guards, direction)
10. G layer (iTerm tmux, Chrome, generic, reorder)
11. Physical trackers (at end)

## Build pipeline

```
src/layers/*.yaml  →  build.py  →  karabiner.json  →  reload Karabiner
```

- `build.py` — assembles YAML sources into the final `karabiner.json`
- `decompose.py` — one-time migration script (JSON → YAML); not needed in normal use
- `compact.py` — converts raw YAML to compact YAML; useful when adding new raw sections

## Files

| File | Purpose |
|------|---------|
| `karabiner.json` | **Generated** — Karabiner Elements reads this file |
| `build.py` | YAML → JSON builder |
| `decompose.py` | One-time JSON → YAML migration |
| `compact.py` | Convert raw YAML files to compact shorthand |
| `src/profile.yaml` | Profile metadata (name, virtual_hid_keyboard, simple_modifications) |
| `src/build_order.yaml` | Controls manipulator priority ordering |
| `src/layers/*.yaml` | Per-layer source files (the actual content) |
| `README.md` | User-facing documentation of all keyboard shortcuts |
