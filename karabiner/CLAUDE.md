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
