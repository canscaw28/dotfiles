#!/usr/bin/env python3
"""Insert R layer manipulators into karabiner.json.

This script:
1. Reads the existing karabiner.json
2. Adds R+E setter after the existing T+E setter (before the T layer setter)
3. Adds R+W setter after the R+E setter
4. Adds R layer setter after the G layer setter
5. Adds 60 action manipulators after the R layer setter
6. Adds guard manipulators after the action manipulators
7. Removes the dead R guard (vk_none for R key)
8. Writes the updated JSON
"""

import json
import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KARABINER_PATH = os.path.join(SCRIPT_DIR, "..", "karabiner", "karabiner.json")

# Import the generator
sys.path.insert(0, SCRIPT_DIR)
from generate_r_layer_karabiner import generate


def find_manipulator_index(manipulators, key_code, conditions_match):
    """Find index of a manipulator by key_code and a condition checker function."""
    for i, m in enumerate(manipulators):
        if m.get("from", {}).get("key_code") == key_code:
            if conditions_match(m.get("conditions", [])):
                return i
    return -1


def has_condition(conditions, name, value):
    """Check if a conditions list has a specific condition."""
    return any(
        c.get("name") == name and c.get("value") == value
        for c in conditions
    )


def main():
    with open(KARABINER_PATH) as f:
        config = json.load(f)

    manipulators = config["profiles"][0]["complex_modifications"]["rules"][0]["manipulators"]
    generated = generate()

    # Step 1: Find the T+E setter (key=e, conditions: caps=1, t=1)
    # and insert R+E setter and R+W setter right after it
    te_idx = find_manipulator_index(
        manipulators, "e",
        lambda conds: has_condition(conds, "t_is_held", 1) and has_condition(conds, "caps_lock_is_held", 1)
    )
    if te_idx == -1:
        print("ERROR: Could not find T+E setter", file=sys.stderr)
        sys.exit(1)
    print(f"Found T+E setter at index {te_idx}")

    # Insert R+E setter and R+W setter right after T+E setter
    # (R+E setter must come before R layer setter to have higher priority when r_is_held=1)
    manipulators.insert(te_idx + 1, generated["r_w_setter"])
    manipulators.insert(te_idx + 1, generated["r_e_setter"])
    print(f"Inserted R+E setter at index {te_idx + 1}")
    print(f"Inserted R+W setter at index {te_idx + 2}")

    # Step 2: Find the G layer setter (key=g, conditions: caps=1 only)
    # and insert R layer setter right after it
    g_idx = find_manipulator_index(
        manipulators, "g",
        lambda conds: (
            has_condition(conds, "caps_lock_is_held", 1)
            and len(conds) == 1
        )
    )
    if g_idx == -1:
        print("ERROR: Could not find G layer setter", file=sys.stderr)
        sys.exit(1)
    print(f"Found G layer setter at index {g_idx}")

    # Insert R layer setter after G layer setter
    manipulators.insert(g_idx + 1, generated["r_layer_setter"])
    print(f"Inserted R layer setter at index {g_idx + 1}")

    # Step 3: Insert action manipulators and guards after R layer setter
    insert_pos = g_idx + 2  # after the R layer setter we just inserted
    for i, action in enumerate(generated["actions"]):
        manipulators.insert(insert_pos + i, action)
    print(f"Inserted {len(generated['actions'])} action manipulators starting at index {insert_pos}")

    insert_pos += len(generated["actions"])
    for i, guard in enumerate(generated["guards"]):
        manipulators.insert(insert_pos + i, guard)
    print(f"Inserted {len(generated['guards'])} guard manipulators starting at index {insert_pos}")

    # Step 4: Remove the dead R guard (key=r, conditions have r=0, t=0, maps to vk_none)
    dead_r_idx = find_manipulator_index(
        manipulators, "r",
        lambda conds: (
            has_condition(conds, "r_is_held", 0)
            and has_condition(conds, "t_is_held", 0)
            and has_condition(conds, "caps_lock_is_held", 1)
        )
    )
    if dead_r_idx != -1:
        m = manipulators[dead_r_idx]
        to_list = m.get("to", [])
        if to_list and to_list[0].get("key_code") == "vk_none":
            manipulators.pop(dead_r_idx)
            print(f"Removed dead R guard at index {dead_r_idx}")
        else:
            print(f"WARNING: Found R manipulator at {dead_r_idx} but it doesn't map to vk_none, skipping")
    else:
        print("WARNING: Could not find dead R guard to remove")

    # Write the updated config
    with open(KARABINER_PATH, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")

    print(f"\nDone! Updated {KARABINER_PATH}")
    print(f"Total manipulators: {len(manipulators)}")


if __name__ == "__main__":
    main()
