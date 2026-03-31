#!/usr/bin/env python3
"""
Idempotent script to add/update F+D (8x8) and F+S (16x16) cursor grid
manipulators to karabiner.json.

Inserts them just before the first F-layer scroll manipulator (the one with
f_is_held=1, s_is_held=0, d_is_held=0) so they have higher priority.
"""

import json
import sys
from pathlib import Path

KARABINER_PATH = Path(__file__).resolve().parent.parent / "karabiner" / "karabiner.json"

DESCRIPTION_PREFIX = "f-cursor-grid"

# Key mappings: (key_code, direction, amount)
# amount < 0 means "jump to edge"
KEY_MAPPINGS = [
    ("h", "left", 1),
    ("j", "down", 1),
    ("k", "up", 1),
    ("l", "right", 1),
    ("y", "left", -1),   # jump to left edge
    ("o", "right", -1),  # jump to right edge
    ("u", "left", 2),
    ("i", "right", 2),
    ("n", "down", -1),   # jump to bottom edge
    ("period", "up", -1),  # jump to top edge
    ("m", "down", 2),
    ("comma", "up", 2),
]


def make_manipulator(key_code, direction, amount, mode_key, grid_size):
    """Create a single cursor grid manipulator."""
    desc = f"{DESCRIPTION_PREFIX}: F+{mode_key.upper()}+{key_code} {direction} {amount}"

    conditions = [
        {"name": "caps_lock_is_held", "type": "variable_if", "value": 1},
        {"name": "f_is_held", "type": "variable_if", "value": 1},
        {"name": f"{mode_key}_is_held", "type": "variable_if", "value": 1},
        {"name": "g_is_held", "type": "variable_if", "value": 0},
        {"name": "t_is_held", "type": "variable_if", "value": 0},
    ]

    hs_cmd = (
        f'/usr/local/bin/hs -c "'
        f"require('cursor_grid').move('{direction}', {amount}, {grid_size})"
        f'" 2>/dev/null &'
    )

    return {
        "conditions": conditions,
        "description": desc,
        "from": {
            "key_code": key_code,
            "modifiers": {"optional": ["any"]},
        },
        "to": [{"shell_command": hs_cmd}],
        "type": "basic",
    }


def generate_all_manipulators():
    """Generate manipulators for both D (8x8) and S (16x16) modes."""
    manipulators = []

    # D mode (8x8)
    for key_code, direction, amount in KEY_MAPPINGS:
        manipulators.append(make_manipulator(key_code, direction, amount, "d", 8))

    # S mode (32x32)
    for key_code, direction, amount in KEY_MAPPINGS:
        manipulators.append(make_manipulator(key_code, direction, amount, "s", 32))

    return manipulators


def find_first_f_scroll_index(manipulators):
    """Find the index of the first F-layer scroll manipulator
    (f_is_held=1, s_is_held=0, d_is_held=0, no description starting with our prefix)."""
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

    # Remove existing cursor grid manipulators
    manipulators = remove_existing(manipulators)

    # Find insertion point
    insert_idx = find_first_f_scroll_index(manipulators)
    if insert_idx is None:
        print("ERROR: Could not find F-layer scroll manipulators to insert before", file=sys.stderr)
        sys.exit(1)

    # Generate and insert
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
