#!/usr/bin/env python3
"""Add T layer workspace operations to karabiner.json.

Generates and inserts:
  - T+W mode setter (pressing w in T layer sets w_is_held)
  - Action manipulators for 7 workspace operations (20 keys each = 140 total):
      T+E       -> ws.sh move        (move window to workspace, stay)
      T+R+E     -> ws.sh move-focus  (move window + follow)
      T+W       -> ws.sh focus       (focus workspace on current monitor)
      T+W+E     -> ws.sh focus-1     (focus workspace on monitor 1)
      T+W+R     -> ws.sh focus-2     (focus workspace on monitor 2)
      T+W+3     -> ws.sh focus-3     (focus workspace on monitor 3)
      T+W+4     -> ws.sh focus-4     (focus workspace on monitor 4)
  - Guard manipulators for T+E and T+W modes

Also ensures existing T layer manipulators have 3_is_held=0 and 4_is_held=0
conditions to prevent conflicts.

Idempotent: removes old workspace components before inserting new ones.
"""

import json
import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KARABINER_PATH = os.path.join(SCRIPT_DIR, "..", "karabiner", "karabiner.json")

# 20 workspace keys: (display_name, karabiner_key_code, ws.sh_argument)
WORKSPACE_KEYS = [
    ("6", "6", "6"),
    ("7", "7", "7"),
    ("8", "8", "8"),
    ("9", "9", "9"),
    ("0", "0", "0"),
    ("y", "y", "y"),
    ("u", "u", "u"),
    ("i", "i", "i"),
    ("o", "o", "o"),
    ("p", "p", "p"),
    ("h", "h", "h"),
    ("j", "j", "j"),
    ("k", "k", "k"),
    ("l", "l", "l"),
    (";", "semicolon", '";"'),
    ("n", "n", "n"),
    ("m", "m", "m"),
    (",", "comma", "comma"),
    (".", "period", "."),
    ("/", "slash", "/"),
]

# Operations: (ws.sh_op, mode_conditions_dict)
# mode_conditions_dict maps variable names to required values.
# Most specific (most positive conditions) first for Karabiner priority.
OPERATIONS = [
    ("move-focus", {"e": 1, "r": 1, "w": 0, "3": 0, "4": 0}),  # T+R+E
    ("focus-1",    {"w": 1, "e": 1, "r": 0, "3": 0, "4": 0}),  # T+W+E
    ("focus-2",    {"w": 1, "r": 1, "e": 0, "3": 0, "4": 0}),  # T+W+R
    ("focus-3",    {"w": 1, "3": 1, "e": 0, "r": 0, "4": 0}),  # T+W+3
    ("focus-4",    {"w": 1, "4": 1, "e": 0, "r": 0, "3": 0}),  # T+W+4
    ("move",       {"e": 1, "r": 0, "w": 0, "3": 0, "4": 0}),  # T+E
    ("focus",      {"w": 1, "e": 0, "r": 0, "3": 0, "4": 0}),  # T+W
]

# Right-hand keys NOT in workspace set that need guards
GUARD_KEYS = [
    "quote", "open_bracket", "close_bracket",
    "hyphen", "equal_sign", "backslash",
]

# Variable names for mode keys used in workspace operations
MODE_VARS = ["e", "r", "w", "3", "4"]


def make_condition(name, value):
    return {"name": name, "type": "variable_if", "value": value}


def get_cond(conditions, name):
    for c in conditions:
        if c.get("name") == name:
            return c.get("value")
    return None


def make_action_manipulator(key_code, shell_cmd, mode_conds):
    """Create an action manipulator for T layer workspace operation."""
    conditions = [
        make_condition("caps_lock_is_held", 1),
        make_condition("a_is_held", 0),
        make_condition("s_is_held", 0),
        make_condition("d_is_held", 0),
        make_condition("f_is_held", 0),
        make_condition("t_is_held", 1),
    ]
    # Add mode variable conditions in consistent order
    for var in MODE_VARS:
        if var in mode_conds:
            conditions.append(make_condition(f"{var}_is_held", mode_conds[var]))
    conditions += [
        make_condition("q_is_held", 0),
        make_condition("g_is_held", 0),
    ]

    return {
        "conditions": conditions,
        "from": {
            "key_code": key_code,
            "modifiers": {"optional": ["any"]},
        },
        "to": [{"shell_command": shell_cmd}],
        "type": "basic",
    }


def make_guard_manipulator(key_code, guard_conds, description):
    """Create a guard/noop manipulator."""
    conditions = [make_condition("caps_lock_is_held", 1), make_condition("t_is_held", 1)]
    for name, value in guard_conds:
        conditions.append(make_condition(name, value))

    return {
        "conditions": conditions,
        "description": description,
        "from": {
            "key_code": key_code,
            "modifiers": {"optional": ["any"]},
        },
        "to": [{"set_variable": {"name": "guard_noop", "value": 0}}],
        "type": "basic",
    }


def make_t_w_setter():
    """T+W mode setter: when t_is_held=1, pressing w sets w_is_held=1."""
    return {
        "conditions": [
            make_condition("caps_lock_is_held", 1),
            make_condition("t_is_held", 1),
        ],
        "from": {
            "key_code": "w",
            "modifiers": {"optional": ["any"]},
        },
        "to": [{"set_variable": {"name": "w_is_held", "value": 1}}],
        "to_after_key_up": [{"set_variable": {"name": "w_is_held", "value": 0}}],
        "type": "basic",
    }


def generate():
    ws_bin = "$HOME/.local/bin/ws.sh"
    actions = []

    for op_name, mode_conds in OPERATIONS:
        for _display, key_code, ws_arg in WORKSPACE_KEYS:
            shell_cmd = f"{ws_bin} {op_name} {ws_arg}"
            actions.append(
                make_action_manipulator(key_code, shell_cmd, mode_conds)
            )

    # T+E guards: block non-workspace keys when E is held in T layer
    e_guards = [
        make_guard_manipulator(kc, [("e_is_held", 1)], "t-ws-guard")
        for kc in GUARD_KEYS
    ]

    # T+W guards: block non-workspace keys when W is held in T layer
    w_guards = [
        make_guard_manipulator(kc, [("w_is_held", 1)], "t-ws-guard")
        for kc in GUARD_KEYS
    ]

    return {
        "t_w_setter": make_t_w_setter(),
        "actions": actions,
        "guards": e_guards + w_guards,
    }


# --- Detection functions ---

def is_t_w_setter(m):
    """Match T+W setter (key=w, t_is_held=1, sets w_is_held)."""
    conds = m.get("conditions", [])
    kc = m.get("from", {}).get("key_code", "")
    to = m.get("to", [{}])[0]
    sv = to.get("set_variable", {})
    return (kc == "w"
            and get_cond(conds, "t_is_held") == 1
            and sv.get("name") == "w_is_held")


def is_t_ws_action(m):
    """Match T layer workspace action (t=1, has shell_command with ws.sh)."""
    conds = m.get("conditions", [])
    to = m.get("to", [{}])[0]
    cmd = to.get("shell_command", "")
    return (get_cond(conds, "t_is_held") == 1
            and "to_after_key_up" not in m
            and "ws.sh" in cmd)


def is_t_ws_guard(m):
    """Match T workspace guard (description=t-ws-guard, or old pattern: t=1, w=1, guard_noop with 3 conds)."""
    if m.get("description") == "t-ws-guard":
        return True
    # Legacy detection: T+W guard with exactly 3 conditions (caps=1, t=1, w=1)
    conds = m.get("conditions", [])
    to = m.get("to", [{}])[0]
    sv = to.get("set_variable", {})
    return (len(conds) == 3
            and get_cond(conds, "t_is_held") == 1
            and get_cond(conds, "w_is_held") == 1
            and sv.get("name") == "guard_noop")


def is_t_layer_manipulator(m):
    """Match any T layer action or guard (t=1, not a setter, not a workspace action)."""
    conds = m.get("conditions", [])
    if get_cond(conds, "t_is_held") != 1:
        return False
    if "to_after_key_up" in m:
        return False
    # Skip workspace actions (ws.sh shell commands)
    to = m.get("to", [{}])[0]
    if "ws.sh" in to.get("shell_command", ""):
        return False
    # Skip workspace guards
    if is_t_ws_guard(m):
        return False
    return True


def find_t_e_setter(manips):
    """Find T+E setter (key=e, t_is_held=1, sets e_is_held)."""
    for i, m in enumerate(manips):
        conds = m.get("conditions", [])
        kc = m.get("from", {}).get("key_code", "")
        to = m.get("to", [{}])[0]
        sv = to.get("set_variable", {})
        if (kc == "e"
                and get_cond(conds, "t_is_held") == 1
                and sv.get("name") == "e_is_held"):
            return i
    return -1


def find_first_t_4_manipulator(manips):
    """Find the first T+4 join action/guard (t=1, 4_is_held=1)."""
    for i, m in enumerate(manips):
        conds = m.get("conditions", [])
        if (get_cond(conds, "t_is_held") == 1
                and get_cond(conds, "4_is_held") == 1
                and "to_after_key_up" not in m):
            return i
    return -1


def main():
    with open(KARABINER_PATH) as f:
        config = json.load(f)

    manips = config["profiles"][0]["complex_modifications"]["rules"][0]["manipulators"]
    generated = generate()

    # Phase 1: Remove old T workspace components
    removed = {"setter": 0, "actions": 0, "guards": 0}
    for i in range(len(manips) - 1, -1, -1):
        m = manips[i]
        if is_t_w_setter(m):
            manips.pop(i)
            removed["setter"] += 1
        elif is_t_ws_action(m):
            manips.pop(i)
            removed["actions"] += 1
        elif is_t_ws_guard(m):
            manips.pop(i)
            removed["guards"] += 1

    print(f"Removed: {removed['setter']} setter, {removed['actions']} actions, {removed['guards']} guards")

    # Phase 2: Add 3_is_held=0 and 4_is_held=0 to all T layer manipulators
    vars_added = {"3_is_held": 0, "4_is_held": 0}
    for m in manips:
        if is_t_layer_manipulator(m):
            conds = m["conditions"]
            for var_name in ["3_is_held", "4_is_held"]:
                if get_cond(conds, var_name) is None:
                    # Insert after w_is_held (or after the last mode variable)
                    insert_after = "w_is_held"
                    for c in conds:
                        if c.get("name") in ("w_is_held", "3_is_held", "4_is_held"):
                            insert_after = c.get("name")
                    for j, c in enumerate(conds):
                        if c.get("name") == insert_after:
                            conds.insert(j + 1, make_condition(var_name, 0))
                            vars_added[var_name] += 1
                            break
    for var_name, count in vars_added.items():
        print(f"Added {var_name}=0 to {count} T layer manipulators")

    # Phase 3: Insert T+W setter after T+E setter
    te_idx = find_t_e_setter(manips)
    if te_idx == -1:
        print("ERROR: Could not find T+E setter", file=sys.stderr)
        sys.exit(1)

    manips.insert(te_idx + 1, generated["t_w_setter"])
    print("Inserted T+W setter after T+E setter")

    # Phase 4: Insert actions and guards before T+4 join manipulators
    t4_first = find_first_t_4_manipulator(manips)
    if t4_first == -1:
        print("ERROR: Could not find T+4 join manipulators", file=sys.stderr)
        sys.exit(1)

    insert_pos = t4_first
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
