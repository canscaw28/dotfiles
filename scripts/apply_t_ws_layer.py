#!/usr/bin/env python3
"""Add T layer workspace operations (T+W, T+E+W) to karabiner.json.

Generates and inserts:
  - T+W mode setter (pressing w in T layer sets w_is_held)
  - T+W action manipulators (20 workspace keys -> ws.sh move)
  - T+E+W action manipulators (20 workspace keys -> ws.sh move-focus) [if enabled]
  - Guard manipulators for non-workspace keys in T+W mode

Also ensures T+E join actions/guards have w_is_held=0 condition to prevent
conflicts with T+E+W mode.

Idempotent: removes old T+W/T+E+W components before inserting new ones.
"""

import json
import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KARABINER_PATH = os.path.join(SCRIPT_DIR, "..", "karabiner", "karabiner.json")

# Same workspace keys as R layer
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

# Operations: (ws.sh_op, t_val, e_val, w_val, r_val)
# Most specific first for Karabiner priority
OPERATIONS = [
    # T+W: move window to workspace (stay on current)
    ("move", 1, 0, 1, 0),
]

# Right-hand keys NOT in workspace set that need guards
GUARD_KEYS = [
    "quote", "open_bracket", "close_bracket",
    "hyphen", "equal_sign", "backslash",
]


def make_condition(name, value):
    return {"name": name, "type": "variable_if", "value": value}


def get_cond(conditions, name):
    for c in conditions:
        if c.get("name") == name:
            return c.get("value")
    return None


def make_action_manipulator(key_code, shell_cmd, t_val, e_val, w_val, r_val):
    """Create an action manipulator for T layer workspace operation."""
    return {
        "conditions": [
            make_condition("caps_lock_is_held", 1),
            make_condition("a_is_held", 0),
            make_condition("s_is_held", 0),
            make_condition("d_is_held", 0),
            make_condition("f_is_held", 0),
            make_condition("t_is_held", t_val),
            make_condition("r_is_held", r_val),
            make_condition("e_is_held", e_val),
            make_condition("w_is_held", w_val),
            make_condition("q_is_held", 0),
            make_condition("g_is_held", 0),
        ],
        "from": {
            "key_code": key_code,
            "modifiers": {"optional": ["any"]},
        },
        "to": [{"shell_command": shell_cmd}],
        "type": "basic",
    }


def make_guard_manipulator(key_code):
    """Create a guard/noop manipulator for T+W mode."""
    return {
        "conditions": [
            make_condition("caps_lock_is_held", 1),
            make_condition("t_is_held", 1),
            make_condition("w_is_held", 1),
        ],
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

    for op_name, t_val, e_val, w_val, r_val in OPERATIONS:
        for _display, key_code, ws_arg in WORKSPACE_KEYS:
            shell_cmd = f"{ws_bin} {op_name} {ws_arg}"
            actions.append(
                make_action_manipulator(key_code, shell_cmd, t_val, e_val, w_val, r_val)
            )

    guards = [make_guard_manipulator(kc) for kc in GUARD_KEYS]

    return {
        "t_w_setter": make_t_w_setter(),
        "actions": actions,
        "guards": guards,
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
    """Match T layer workspace action (t=1, w=1, has shell_command with ws.sh)."""
    conds = m.get("conditions", [])
    to = m.get("to", [{}])[0]
    return (get_cond(conds, "t_is_held") == 1
            and get_cond(conds, "w_is_held") == 1
            and "shell_command" in to)


def is_t_ws_guard(m):
    """Match T+W guard (t=1, w=1, sets guard_noop)."""
    conds = m.get("conditions", [])
    to = m.get("to", [{}])[0]
    sv = to.get("set_variable", {})
    return (get_cond(conds, "t_is_held") == 1
            and get_cond(conds, "w_is_held") == 1
            and sv.get("name") == "guard_noop")


def is_t_e_manipulator(m):
    """Match T+E join action or guard (t=1, e=1, r=0, not a setter)."""
    conds = m.get("conditions", [])
    to = m.get("to", [{}])[0]
    sv = to.get("set_variable", {})
    # Must be t=1, e=1, r=0
    if get_cond(conds, "t_is_held") != 1:
        return False
    if get_cond(conds, "e_is_held") != 1:
        return False
    if get_cond(conds, "r_is_held") != 0:
        return False
    # Must not be a setter (setters have to_after_key_up)
    if "to_after_key_up" in m:
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


def find_first_t_e_manipulator(manips):
    """Find the first T+E join action/guard in the list."""
    for i, m in enumerate(manips):
        if is_t_e_manipulator(m):
            return i
    return -1


def main():
    with open(KARABINER_PATH) as f:
        config = json.load(f)

    manips = config["profiles"][0]["complex_modifications"]["rules"][0]["manipulators"]
    generated = generate()

    # Phase 1: Remove old T+W components
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

    # Phase 2: Add w_is_held=0 to T+E join actions/guards (if not already present)
    w_added = 0
    for m in manips:
        if is_t_e_manipulator(m):
            conds = m["conditions"]
            if get_cond(conds, "w_is_held") is None:
                # Insert w_is_held=0 after e_is_held
                for j, c in enumerate(conds):
                    if c.get("name") == "e_is_held":
                        conds.insert(j + 1, make_condition("w_is_held", 0))
                        w_added += 1
                        break
    print(f"Added w_is_held=0 to {w_added} T+E manipulators")

    # Phase 3: Insert T+W setter after T+E setter
    te_idx = find_t_e_setter(manips)
    if te_idx == -1:
        print("ERROR: Could not find T+E setter", file=sys.stderr)
        sys.exit(1)

    manips.insert(te_idx + 1, generated["t_w_setter"])
    print("Inserted T+W setter after T+E setter")

    # Phase 4: Insert actions and guards before T+E join manipulators
    te_first = find_first_t_e_manipulator(manips)
    if te_first == -1:
        print("ERROR: Could not find T+E join manipulators", file=sys.stderr)
        sys.exit(1)

    insert_pos = te_first
    for j, action in enumerate(generated["actions"]):
        manips.insert(insert_pos + j, action)
    print(f"Inserted {len(generated['actions'])} action manipulators before T+E join")

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
