# Karabiner Configuration

**NEVER edit `karabiner.json` directly — it is a generated build artifact.**

The source of truth is `src/layers/*.yaml` (one file per layer, plus infrastructure and the help trigger).

## Workflow

1. Edit the relevant YAML file under `src/layers/`
2. Run `./reload.sh --karabiner` from the repo root (builds via `build.py` then reloads Karabiner). Running `build.py` alone only updates the repo copy — the live `~/.config/karabiner/karabiner.json` keeps the old bindings until `reload.sh` runs.
3. Verify with `python3 build.py --check` (exits 0 if `karabiner.json` matches what would be built from sources)

If you find yourself wanting to edit `karabiner.json` directly, stop and find the corresponding YAML source file.

## File structure

```
karabiner/src/layers/
├── q-setter.yaml         # Q layer setter (built first so it wins over everything)
├── infrastructure.yaml   # Caps lock setup, layer setters, physical trackers
├── help.yaml             # caps+/ help overlay trigger
├── a-system.yaml         # A layer (Dock, Notification Center, input source)
├── default.yaml          # Default layer (cursor, selection, deletion, iTerm overrides)
├── f.yaml                # F layer (scroll, cursor grid, link hints)
├── t.yaml                # T layer (focus/move/join, workspace operations, nav)
├── q.yaml                # Q layer (surround with symbol pairs)
├── r.yaml                # R layer (Superhuman)
└── g.yaml                # G layer (Chrome tabs, iTerm tmux panes, generic, tab move/reorder)
```

`build_order.yaml` controls the ordering.

Calls into Hammerspoon go through `$HOME/.local/bin/hsq "<lua>"`, never `hs -c` (see `scripts/hsq.c` for why).

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
      - shell: '$HOME/.local/bin/hsq "require(''chrome_tabs'').onKeyDown(-1)" &'
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
always_negative: [panel_active]   # Optional: non-layer vars to set =0 on every
                                  # manipulator in the section, ignored by
                                  # per-manipulator negative_conditions overrides

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
README.md          →  build_help.py  →  ../.hammerspoon/help_data.json  (help overlay)
```

- `build.py` — assembles YAML sources into the final `karabiner.json`, and runs `build_help.py`
- `build_help.py` — parses the README's layer tables into the help overlay's data; `--check` fails if it's stale

## Files

| File | Purpose |
|------|---------|
| `karabiner.json` | **Generated** — Karabiner Elements reads this file |
| `build.py` | YAML → JSON builder |
| `src/profile.yaml` | Profile metadata (name, virtual_hid_keyboard, simple_modifications) |
| `src/build_order.yaml` | Controls manipulator priority ordering |
| `build_help.py` | README → `.hammerspoon/help_data.json` for the `⇪+/` overlay |
| `src/layers/*.yaml` | Per-layer source files |
| `README.md` | User-facing documentation of all keyboard shortcuts (also the help overlay's source) |
