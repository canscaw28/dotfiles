#!/usr/bin/python3
"""Generate T layer workspace operation YAML source files.

Generates:
  27-t-ws-actions.yaml  — 120 workspace actions (6 operations × 20 keys)
  28-t-nav.yaml         — 4 nav actions (T+W+4+HJKL)
  29-t-ws-guards.yaml   — 26 guard manipulators (T+W, T+E, T+W+4)

Operations:
  T+R+E   -> ws.sh move-focus     (move window + follow)
  T+W+E   -> ws.sh focus-1        (focus workspace on monitor 1)
  T+W+R   -> ws.sh focus-2        (focus workspace on monitor 2)
  T+W     -> ws.sh focus          (focus workspace on current monitor)
  T+E     -> ws.sh move           (move window to workspace, stay)
  T+3     -> ws.sh swap-windows   (swap all windows between workspaces)

This script writes YAML source files only. It does NOT modify
karabiner.json directly. Run `./reload.sh --karabiner` after to rebuild.

To add a workspace key or change operations, edit WORKSPACE_KEYS or
OPERATIONS below and re-run.
"""

import os

import yaml

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYERS_DIR = os.path.join(REPO_ROOT, "karabiner", "src", "layers")

ACTIONS_FILE = os.path.join(LAYERS_DIR, "t-ws-actions.yaml")
NAV_FILE = os.path.join(LAYERS_DIR, "t-nav.yaml")
GUARDS_FILE = os.path.join(LAYERS_DIR, "t-ws-guards.yaml")

WS_BIN = "$HOME/.local/bin/ws.sh"

# 20 workspace keys: (karabiner_key_code, ws.sh argument)
WORKSPACE_KEYS = [
    ("6", "6"),
    ("7", "7"),
    ("8", "8"),
    ("9", "9"),
    ("0", "0"),
    ("y", "y"),
    ("u", "u"),
    ("i", "i"),
    ("o", "o"),
    ("p", "p"),
    ("h", "h"),
    ("j", "j"),
    ("k", "k"),
    ("l", "l"),
    ("semicolon", '";"'),
    ("n", "n"),
    ("m", "m"),
    ("comma", "comma"),
    ("period", "."),
    ("slash", "/"),
]

# Operations with their layer requirements and modifier flags.
# Modifier flags encode the operation mode so the ws_grid eventtap can
# decode it from the key event without async IPC.
OPERATIONS = [
    {
        "op": "move-focus",
        "layer": ["caps", "t", "e", "r"],
        "negatives": ["a", "s", "d", "f", "w", "3", "4", "q", "g"],
        "modifiers": ["fn", "control"],
    },
    {
        "op": "focus-1",
        "layer": ["caps", "t", "w", "e"],
        "negatives": ["a", "s", "d", "f", "r", "3", "4", "q", "g"],
        "modifiers": ["fn", "shift", "control"],
    },
    {
        "op": "focus-2",
        "layer": ["caps", "t", "w", "r"],
        "negatives": ["a", "s", "d", "f", "e", "3", "4", "q", "g"],
        "modifiers": ["fn", "option"],
    },
    {
        "op": "focus",
        "layer": ["caps", "t", "w"],
        "negatives": ["a", "s", "d", "f", "e", "r", "3", "4", "q", "g"],
        "modifiers": ["fn"],
    },
    {
        "op": "move",
        "layer": ["caps", "t", "e"],
        "negatives": ["a", "s", "d", "f", "r", "w", "3", "4", "q", "g"],
        "modifiers": ["fn", "shift"],
    },
    {
        "op": "swap-windows",
        "layer": ["caps", "t", "3"],
        "negatives": ["a", "s", "d", "f", "r", "e", "w", "4", "q", "g"],
        "modifiers": ["fn", "shift", "control", "option"],
    },
]

# Right-hand keys NOT in workspace set that need guards
GUARD_KEYS = ["open_bracket", "close_bracket", "hyphen", "equal_sign", "backslash"]

# Direction keys for nav mode (HJKL only)
NAV_HJKL = ["h", "j", "k", "l"]

# Non-HJKL workspace keys needing guards in nav mode
_HJKL_SET = {"h", "j", "k", "l"}
WS_NON_HJKL = [kc for kc, _ in WORKSPACE_KEYS if kc not in _HJKL_SET]


def make_action(key_code, ws_arg, op_spec):
    """Make a single workspace action manipulator in compact format."""
    mod_str = "+".join(op_spec["modifiers"])
    return {
        "from": key_code,
        "to": [
            [key_code, mod_str],
            {"shell": f"{WS_BIN} {op_spec['op']} {ws_arg}"},
        ],
    }


def make_nav_manipulator(key):
    """T+W+4+key for nav mode (handled by ws_grid eventtap)."""
    return {
        "from": key,
        "description": "t-nav-action",
        "to": [key, "fn+command"],
    }


def make_guard(key_code, layer, negatives):
    """Guard manipulator that absorbs a key without action."""
    return {
        "from": key_code,
        "description": "t-ws-guard",
        "layer": layer,
        "negative_conditions": negatives,
        "to": "noop",
    }


def write_yaml(filepath, data):
    output = {
        "_generated_by": "scripts/apply_t_ws_layer.py",
        "_warning": "Auto-generated. Do not edit directly.",
    }
    output.update(data)
    with open(filepath, "w") as f:
        yaml.dump(output, f, default_flow_style=False, allow_unicode=True, sort_keys=False, width=200)


def generate_actions():
    """Build the workspace actions file with all 6 operations."""
    # Each operation has different conditions, so we need per-manipulator overrides.
    # Use the first operation as the file-level layer.
    first = OPERATIONS[0]
    manipulators = []

    for op_idx, op_spec in enumerate(OPERATIONS):
        for key_code, ws_arg in WORKSPACE_KEYS:
            m = make_action(key_code, ws_arg, op_spec)
            # First operation matches file-level layer; others need overrides
            if op_idx > 0:
                m["layer"] = op_spec["layer"]
                m["negative_conditions"] = op_spec["negatives"]
            manipulators.append(m)

    return {
        "layer": first["layer"],
        "negative_conditions": first["negatives"],
        "manipulators": manipulators,
    }


def generate_nav():
    """Build the nav action file."""
    return {
        "layer": ["caps", "t", "w", "4"],
        "negative_conditions": ["a", "s", "d", "f", "e", "r", "3", "q", "g"],
        "manipulators": [make_nav_manipulator(k) for k in NAV_HJKL],
    }


def generate_guards():
    """Build the guards file."""
    manipulators = []

    # T+E guards (block non-workspace keys when E is held in T layer)
    for kc in GUARD_KEYS:
        manipulators.append(make_guard(kc, ["caps", "t", "e"], []))

    # T+W guards
    for kc in GUARD_KEYS:
        manipulators.append(make_guard(kc, ["caps", "t", "w"], []))

    # T+W+4 nav mode guards (block non-HJKL workspace keys)
    for kc in WS_NON_HJKL:
        manipulators.append(make_guard(kc, ["caps", "t", "w", "4"], []))

    return {"manipulators": manipulators}


def main():
    write_yaml(ACTIONS_FILE, generate_actions())
    print(f"Wrote {len(OPERATIONS) * len(WORKSPACE_KEYS)} actions to {os.path.basename(ACTIONS_FILE)}")

    write_yaml(NAV_FILE, generate_nav())
    print(f"Wrote {len(NAV_HJKL)} nav actions to {os.path.basename(NAV_FILE)}")

    write_yaml(GUARDS_FILE, generate_guards())
    total_guards = len(GUARD_KEYS) * 2 + len(WS_NON_HJKL)
    print(f"Wrote {total_guards} guards to {os.path.basename(GUARDS_FILE)}")


if __name__ == "__main__":
    main()
