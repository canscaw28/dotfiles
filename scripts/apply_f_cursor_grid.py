#!/usr/bin/env python3
"""
Idempotent script to add/update F layer cursor grid manipulators to karabiner.json.

Modes:
  F+D (8x8)  — grid-based cursor movement
  F+S (32x32) — fine grid-based cursor movement
  F+E         — fixed-position jumps (edges, corners, quadrant centers)
  F+D/S/E+P   — toggle grid overlay

Inserts before the first F-layer scroll manipulator for correct priority.
"""

import json
import sys
from pathlib import Path

KARABINER_PATH = Path(__file__).resolve().parent.parent / "karabiner" / "karabiner.json"

DESCRIPTION_PREFIX = "f-cursor-grid"

# Grid movement keys: (key_code, direction, amount)
# amount < 0 means "jump to edge"
MOVE_KEYS = [
    ("h", "left", 1),
    ("j", "down", 1),
    ("k", "up", 1),
    ("l", "right", 1),
    ("y", "left", -1),     # jump to left edge
    ("o", "right", -1),    # jump to right edge
    ("u", "left", 2),
    ("i", "right", 2),
    ("n", "down", -1),     # jump to bottom edge
    ("period", "up", -1),  # jump to top edge
    ("m", "down", 2),
    ("comma", "up", 2),
]

# Fixed-position jump keys for F+E mode
JUMP_KEYS = [
    "h", "j", "k", "l", "semicolon",
    "y", "o", "n", "period",
    "u", "i", "m", "comma",
]


def make_conditions(mode_key):
    """Base conditions for an F+mode manipulator."""
    return [
        {"name": "caps_lock_is_held", "type": "variable_if", "value": 1},
        {"name": "f_is_held", "type": "variable_if", "value": 1},
        {"name": f"{mode_key}_is_held", "type": "variable_if", "value": 1},
        {"name": "g_is_held", "type": "variable_if", "value": 0},
        {"name": "t_is_held", "type": "variable_if", "value": 0},
    ]


def make_move_manipulator(key_code, direction, amount, mode_key, grid_size):
    """Create a grid movement manipulator (F+D or F+S) with hold-to-repeat."""
    desc = f"{DESCRIPTION_PREFIX}: F+{mode_key.upper()}+{key_code} {direction} {amount}"
    start_cmd = (
        f'/usr/local/bin/hs -c "'
        f"require('cursor_grid').startMove('{direction}', {amount}, {grid_size})"
        f'" 2>/dev/null &'
    )
    stop_cmd = (
        '/usr/local/bin/hs -c "'
        "require('cursor_grid').stopMove()"
        '" 2>/dev/null &'
    )
    return {
        "conditions": make_conditions(mode_key),
        "description": desc,
        "from": {"key_code": key_code, "modifiers": {"optional": ["any"]}},
        "to": [{"shell_command": start_cmd}],
        "to_after_key_up": [{"shell_command": stop_cmd}],
        "type": "basic",
    }


def make_jump_manipulator(key_code):
    """Create a fixed-position jump manipulator (F+E)."""
    desc = f"{DESCRIPTION_PREFIX}: F+E+{key_code} jump"
    hs_cmd = (
        f'/usr/local/bin/hs -c "'
        f"require('cursor_grid').jump('{key_code}')"
        f'" 2>/dev/null &'
    )
    return {
        "conditions": make_conditions("e"),
        "description": desc,
        "from": {"key_code": key_code, "modifiers": {"optional": ["any"]}},
        "to": [{"shell_command": hs_cmd}],
        "type": "basic",
    }


def make_grid_toggle(mode_key, grid_size, mode="move"):
    """Create a grid overlay toggle manipulator (F+mode+P)."""
    desc = f"{DESCRIPTION_PREFIX}: F+{mode_key.upper()}+P toggle grid"
    hs_cmd = (
        f'/usr/local/bin/hs -c "'
        f"require('cursor_grid').toggleGrid({grid_size}, \'{mode}\')"
        f'" 2>/dev/null &'
    )
    return {
        "conditions": make_conditions(mode_key),
        "description": desc,
        "from": {"key_code": "p", "modifiers": {"optional": ["any"]}},
        "to": [{"shell_command": hs_cmd}],
        "type": "basic",
    }


def generate_all_manipulators():
    """Generate all cursor grid manipulators."""
    ms = []

    # D mode (8x8) movement
    for key_code, direction, amount in MOVE_KEYS:
        ms.append(make_move_manipulator(key_code, direction, amount, "d", 8))

    # S mode (32x32) movement
    for key_code, direction, amount in MOVE_KEYS:
        ms.append(make_move_manipulator(key_code, direction, amount, "s", 32))

    # E mode fixed-position jumps
    for key_code in JUMP_KEYS:
        ms.append(make_jump_manipulator(key_code))

    # Grid overlay toggles
    ms.append(make_grid_toggle("d", 8))
    ms.append(make_grid_toggle("s", 32))
    ms.append(make_grid_toggle("e", 8, "jump"))

    return ms


def find_first_f_scroll_index(manipulators):
    """Find the index of the first F-layer scroll manipulator."""
    for i, m in enumerate(manipulators):
        conditions = m.get("conditions", [])
        cond_map = {}
        for c in conditions:
            if c.get("type") == "variable_if":
                cond_map[c["name"]] = c["value"]

        if (
            cond_map.get("f_is_held") == 1
            and cond_map.get("s_is_held") == 0
            and cond_map.get("d_is_held") == 0
            and cond_map.get("caps_lock_is_held") == 1
            and cond_map.get("g_is_held") == 0
        ):
            desc = m.get("description", "")
            if not desc.startswith(DESCRIPTION_PREFIX):
                return i
    return None


def remove_existing(manipulators):
    """Remove any existing cursor grid manipulators."""
    return [m for m in manipulators if not m.get("description", "").startswith(DESCRIPTION_PREFIX)]


def main():
    with open(KARABINER_PATH) as f:
        config = json.load(f)

    rule = config["profiles"][0]["complex_modifications"]["rules"][0]
    manipulators = rule["manipulators"]

    manipulators = remove_existing(manipulators)

    insert_idx = find_first_f_scroll_index(manipulators)
    if insert_idx is None:
        print("ERROR: Could not find F-layer scroll manipulators to insert before", file=sys.stderr)
        sys.exit(1)

    new_manipulators = generate_all_manipulators()
    for i, m in enumerate(new_manipulators):
        manipulators.insert(insert_idx + i, m)

    rule["manipulators"] = manipulators

    with open(KARABINER_PATH, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Inserted {len(new_manipulators)} cursor grid manipulators at index {insert_idx}")


if __name__ == "__main__":
    main()
