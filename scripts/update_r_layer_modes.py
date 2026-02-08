#!/usr/bin/env python3
"""Update R layer mode assignments in karabiner.json.

Changes:
  - R+W setter: add e_is_held=1 condition (W is now sub-mode of R+E)
  - Old R+E actions (r=1,e=1,w=0): flip w to 1 → becomes R+E+W (move+follow)
  - Old R+W actions (r=1,e=0,w=1): swap e→1,w→0 → becomes R+E (move, stay)
  - Add W guard for R layer
"""

import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KARABINER_PATH = os.path.join(SCRIPT_DIR, "..", "karabiner", "karabiner.json")


def get_cond(conditions, name):
    for c in conditions:
        if c.get("name") == name:
            return c
    return None


def set_cond_value(conditions, name, value):
    c = get_cond(conditions, name)
    if c:
        c["value"] = value


def main():
    with open(KARABINER_PATH) as f:
        config = json.load(f)

    manips = config["profiles"][0]["complex_modifications"]["rules"][0]["manipulators"]

    # 1. Update R+W setter: add e_is_held=1 condition
    for m in manips:
        if (m.get("from", {}).get("key_code") == "w"
                and get_cond(m.get("conditions", []), "r_is_held")
                and get_cond(m.get("conditions", []), "r_is_held")["value"] == 1
                and not get_cond(m.get("conditions", []), "t_is_held")
                and m.get("to", [{}])[0].get("set_variable", {}).get("name") == "w_is_held"):
            m["conditions"].append({"name": "e_is_held", "type": "variable_if", "value": 1})
            print("Updated R+W setter: added e_is_held=1 condition")
            break

    # 2. Update action manipulators
    old_re_count = 0
    old_rw_count = 0
    for m in manips:
        conds = m.get("conditions", [])
        r = get_cond(conds, "r_is_held")
        e = get_cond(conds, "e_is_held")
        w = get_cond(conds, "w_is_held")
        t = get_cond(conds, "t_is_held")

        if not (r and e and w and t):
            continue
        if r["value"] != 1 or t["value"] != 0:
            continue

        to = m.get("to", [{}])[0]
        mods = to.get("modifiers", [])

        # Old R+E (r=1, e=1, w=0) with ctrl+alt+shift → flip w to 1
        if e["value"] == 1 and w["value"] == 0 and "option" in mods:
            w["value"] = 1
            old_re_count += 1

        # Old R+W (r=1, e=0, w=1) with cmd+ctrl+shift → swap e↔w
        elif e["value"] == 0 and w["value"] == 1 and "command" in mods:
            e["value"] = 1
            w["value"] = 0
            old_rw_count += 1

    print(f"Updated {old_re_count} old R+E actions → R+E+W (move+follow)")
    print(f"Updated {old_rw_count} old R+W actions → R+E (move, stay)")

    # 3. Add W guard for R layer (insert after existing R layer guards)
    # Find the last R layer guard (r=1, t=0, guard_noop)
    last_guard_idx = -1
    for i, m in enumerate(manips):
        conds = m.get("conditions", [])
        r = get_cond(conds, "r_is_held")
        t = get_cond(conds, "t_is_held")
        to = m.get("to", [{}])[0]
        if (r and r["value"] == 1
                and t and t["value"] == 0
                and to.get("set_variable", {}).get("name") == "guard_noop"):
            last_guard_idx = i

    if last_guard_idx >= 0:
        w_guard = {
            "conditions": [
                {"name": "caps_lock_is_held", "type": "variable_if", "value": 1},
                {"name": "r_is_held", "type": "variable_if", "value": 1},
                {"name": "t_is_held", "type": "variable_if", "value": 0},
            ],
            "from": {"key_code": "w", "modifiers": {"optional": ["any"]}},
            "to": [{"set_variable": {"name": "guard_noop", "value": 0}}],
            "type": "basic",
        }
        manips.insert(last_guard_idx + 1, w_guard)
        print(f"Inserted W guard at index {last_guard_idx + 1}")

    with open(KARABINER_PATH, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")

    print("Done!")


if __name__ == "__main__":
    main()
