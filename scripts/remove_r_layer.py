#!/usr/bin/env python3
"""Remove all R layer manipulators from karabiner.json.

Removes:
  - R mode setters (R+E, R+W, R+Q)
  - R action manipulators (shell_command with ws.sh, r=1, t=0)
  - R guard manipulators (guard_noop, r=1, t=0, 3 conditions)
  - R layer setter (caps+R -> r_is_held)

One-time migration script.
"""

import json
import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KARABINER_PATH = os.path.join(SCRIPT_DIR, "..", "karabiner", "karabiner.json")


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

    if kc == "e" and get_cond(conds, "r_is_held") == 1 and get_cond(conds, "t_is_held") is None:
        if sv.get("name") == "e_is_held":
            return True
    if kc == "w" and get_cond(conds, "r_is_held") == 1:
        if sv.get("name") == "w_is_held":
            return True
    if kc == "q" and get_cond(conds, "r_is_held") == 1:
        if sv.get("name") == "q_is_held":
            return True
    return False


def is_r_action(m):
    """Match R layer action manipulators (r=1, t=0, has shell_command)."""
    conds = m.get("conditions", [])
    to = m.get("to", [{}])[0]
    if get_cond(conds, "r_is_held") != 1:
        return False
    if get_cond(conds, "t_is_held") != 0:
        return False
    if "shell_command" not in to and "modifiers" not in to:
        return False
    return True


def is_r_guard(m):
    """Match R layer guard manipulators (r=1, t=0, guard_noop, 3 conditions)."""
    conds = m.get("conditions", [])
    to = m.get("to", [{}])[0]
    if get_cond(conds, "r_is_held") != 1:
        return False
    if get_cond(conds, "t_is_held") != 0:
        return False
    sv = to.get("set_variable", {})
    if sv.get("name") != "guard_noop":
        return False
    if len(conds) == 3:
        return True
    return False


def is_r_layer_setter(m):
    """Match R layer setter (key=r, only caps_lock_is_held=1 condition)."""
    conds = m.get("conditions", [])
    kc = m.get("from", {}).get("key_code", "")
    to = m.get("to", [{}])[0]
    sv = to.get("set_variable", {})
    return (kc == "r" and len(conds) == 1
            and get_cond(conds, "caps_lock_is_held") == 1
            and sv.get("name") == "r_is_held")


def main():
    with open(KARABINER_PATH) as f:
        config = json.load(f)

    manips = config["profiles"][0]["complex_modifications"]["rules"][0]["manipulators"]

    removed = {"setters": 0, "actions": 0, "guards": 0, "layer_setter": 0}
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
        elif is_r_layer_setter(m):
            manips.pop(i)
            removed["layer_setter"] += 1

    print(f"Removed: {removed['layer_setter']} layer setter, {removed['setters']} mode setters, "
          f"{removed['actions']} actions, {removed['guards']} guards")

    with open(KARABINER_PATH, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")

    print(f"Done! Total manipulators: {len(manips)}")


if __name__ == "__main__":
    main()
