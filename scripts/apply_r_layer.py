#!/usr/bin/env python3
"""Replace R layer manipulators in karabiner.json with freshly generated ones.

Finds existing R layer components by their signatures and replaces them:
  - R mode setters (R+E, R+W, R+Q) → replaced with generated setters
  - R action manipulators → replaced with generated actions
  - R guard manipulators → replaced with generated guards

Preserves T layer setter, G layer setter, R layer setter, and all non-R manipulators.
"""

import json
import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KARABINER_PATH = os.path.join(SCRIPT_DIR, "..", "karabiner", "karabiner.json")

sys.path.insert(0, SCRIPT_DIR)
from generate_r_layer_karabiner import generate


def get_cond(conditions, name):
    for c in conditions:
        if c.get("name") == name:
            return c.get("value")
    return None


def is_r_mode_setter(m):
    """Match R+E setter, R+W setter, or R+Q setter (but NOT T+E setter or T+R setter)."""
    conds = m.get("conditions", [])
    kc = m.get("from", {}).get("key_code", "")
    to = m.get("to", [{}])[0]
    sv = to.get("set_variable", {})

    # R+E setter: key=e, r_is_held=1, no t_is_held condition, sets e_is_held
    if kc == "e" and get_cond(conds, "r_is_held") == 1 and get_cond(conds, "t_is_held") is None:
        if sv.get("name") == "e_is_held":
            return True

    # R+W setter: key=w, r_is_held=1, sets w_is_held
    if kc == "w" and get_cond(conds, "r_is_held") == 1:
        if sv.get("name") == "w_is_held":
            return True

    # R+Q setter: key=q, r_is_held=1, sets q_is_held
    if kc == "q" and get_cond(conds, "r_is_held") == 1:
        if sv.get("name") == "q_is_held":
            return True

    return False


def is_r_action(m):
    """Match R layer action manipulators (r=1, t=0, has modifier or shell_command output)."""
    conds = m.get("conditions", [])
    to = m.get("to", [{}])[0]

    if get_cond(conds, "r_is_held") != 1:
        return False
    if get_cond(conds, "t_is_held") != 0:
        return False
    # Must have action output (modifiers or shell_command), not set_variable (setter/guard)
    if "shell_command" not in to and "modifiers" not in to:
        return False
    return True


def is_r_guard(m):
    """Match R layer guard manipulators (r=1, t=0, sets guard_noop)."""
    conds = m.get("conditions", [])
    to = m.get("to", [{}])[0]

    if get_cond(conds, "r_is_held") != 1:
        return False
    if get_cond(conds, "t_is_held") != 0:
        return False
    # Must be a guard (sets guard_noop)
    sv = to.get("set_variable", {})
    if sv.get("name") != "guard_noop":
        return False
    # Must NOT have e_is_held=1 or r_is_held in conditions suggesting T layer
    # (T layer guards also have r=1, t=0, but they also have e=1 for R+E+T guards)
    # Actually, pure R guards only have: caps=1, r=1, t=0 (3 conditions)
    # T layer guards have more conditions
    if len(conds) == 3:
        return True
    return False


def find_r_layer_setter(manips):
    """Find the R layer setter (key=r, only caps_lock_is_held=1 condition)."""
    for i, m in enumerate(manips):
        conds = m.get("conditions", [])
        kc = m.get("from", {}).get("key_code", "")
        to = m.get("to", [{}])[0]
        sv = to.get("set_variable", {})
        if (kc == "r" and len(conds) == 1
                and get_cond(conds, "caps_lock_is_held") == 1
                and sv.get("name") == "r_is_held"):
            return i
    return -1


def find_t_layer_setter(manips):
    """Find the T layer setter (key=t, only caps_lock_is_held=1 condition)."""
    for i, m in enumerate(manips):
        conds = m.get("conditions", [])
        kc = m.get("from", {}).get("key_code", "")
        to = m.get("to", [{}])[0]
        sv = to.get("set_variable", {})
        if (kc == "t" and len(conds) == 1
                and get_cond(conds, "caps_lock_is_held") == 1
                and sv.get("name") == "t_is_held"):
            return i
    return -1


def main():
    with open(KARABINER_PATH) as f:
        config = json.load(f)

    manips = config["profiles"][0]["complex_modifications"]["rules"][0]["manipulators"]
    generated = generate()

    # Phase 1: Remove old R layer components (iterate backwards to preserve indices)
    removed = {"setters": 0, "actions": 0, "guards": 0}
    for i in range(len(manips) - 1, -1, -1):
        m = manips[i]
        if is_r_mode_setter(m):
            manips.pop(i)
            removed["setters"] += 1
        elif is_r_action(m):
            manips.pop(i)
            removed["actions"] += 1
        elif is_r_guard(m):
            manips.pop(i)
            removed["guards"] += 1

    print(f"Removed: {removed['setters']} setters, {removed['actions']} actions, {removed['guards']} guards")

    # Phase 2: Insert new R layer components

    # Insert mode setters before T layer setter (so they have higher priority when r=1)
    t_idx = find_t_layer_setter(manips)
    if t_idx == -1:
        print("ERROR: Could not find T layer setter", file=sys.stderr)
        sys.exit(1)

    setters = []
    if "r_q_setter" in generated:
        setters.append(generated["r_q_setter"])
    if "r_w_setter" in generated:
        setters.append(generated["r_w_setter"])
    setters.append(generated["r_e_setter"])

    for j, setter in enumerate(setters):
        manips.insert(t_idx + j, setter)
    print(f"Inserted {len(setters)} setter(s) before T layer setter")

    # Insert actions and guards after R layer setter
    r_idx = find_r_layer_setter(manips)
    if r_idx == -1:
        print("ERROR: Could not find R layer setter", file=sys.stderr)
        sys.exit(1)

    insert_pos = r_idx + 1
    for j, action in enumerate(generated["actions"]):
        manips.insert(insert_pos + j, action)
    print(f"Inserted {len(generated['actions'])} action manipulators")

    insert_pos += len(generated["actions"])
    for j, guard in enumerate(generated["guards"]):
        manips.insert(insert_pos + j, guard)
    print(f"Inserted {len(generated['guards'])} guard manipulators")

    # Write the updated config
    with open(KARABINER_PATH, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")

    print(f"\nDone! Total manipulators: {len(manips)}")


if __name__ == "__main__":
    main()
