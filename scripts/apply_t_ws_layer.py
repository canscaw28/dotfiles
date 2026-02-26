#!/usr/bin/env python3
"""Add T layer workspace operations to karabiner.json.

Generates and inserts:
  - T+W and T+Q mode setters
  - Action manipulators for 10 workspace operations (20 keys each = 200 total):
      T+W       -> ws.sh focus          (focus workspace on current monitor)
      T+E       -> ws.sh move           (move window to workspace, stay)
      T+R+E     -> ws.sh move-focus     (move window + follow)
      T+W+E     -> ws.sh focus-1        (focus workspace on monitor 1)
      T+W+R     -> ws.sh focus-2        (focus workspace on monitor 2)
      T+W+3     -> ws.sh focus-3        (focus workspace on monitor 3)
      T+W+4     -> ws.sh focus-4        (focus workspace on monitor 4)
      T+Q       -> ws.sh swap-windows   (swap all windows between workspaces)
      T+Q+3     -> ws.sh push-windows   (push all windows to target workspace)
      T+Q+E     -> ws.sh pull-windows   (pull all windows from target workspace)
  - Guard manipulators for T+E, T+W, and T+Q modes

Also ensures existing T layer manipulators have 3_is_held=0, 4_is_held=0,
and q_is_held=0 conditions to prevent conflicts.

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

# Operations: (ws.sh_op, mode_conditions_dict, extra_modifiers)
# mode_conditions_dict maps variable names to required values.
# Each mode key that isn't part of the combo is explicitly set to 0.
# extra_modifiers are added to the fn key event so the eventtap can decode
# the operation mode from flags, bypassing unreliable async keyDown/keyUp IPC.
OPERATIONS = [
    ("move-focus",    {"e": 1, "r": 1, "w": 0, "3": 0, "4": 0, "q": 0}, ["control"]),                   # T+R+E
    ("focus-1",       {"w": 1, "e": 1, "r": 0, "3": 0, "4": 0, "q": 0}, ["shift", "control"]),           # T+W+E
    ("focus-2",       {"w": 1, "r": 1, "e": 0, "3": 0, "4": 0, "q": 0}, ["option"]),                     # T+W+R
    ("focus-3",       {"w": 1, "3": 1, "e": 0, "r": 0, "4": 0, "q": 0}, ["shift", "option"]),            # T+W+3
    ("focus-4",       {"w": 1, "4": 1, "e": 0, "r": 0, "3": 0, "q": 0}, ["control", "option"]),          # T+W+4
    ("focus",         {"w": 1, "e": 0, "r": 0, "3": 0, "4": 0, "q": 0}, []),                             # T+W
    ("move",          {"e": 1, "r": 0, "w": 0, "3": 0, "4": 0, "q": 0}, ["shift"]),                      # T+E
    ("push-windows",  {"q": 1, "3": 1, "e": 0, "r": 0, "w": 0, "4": 0}, ["command"]),                    # T+Q+3
    ("pull-windows",  {"q": 1, "e": 1, "3": 0, "r": 0, "w": 0, "4": 0}, ["command", "shift"]),           # T+Q+E
    ("swap-windows",  {"q": 1, "e": 0, "r": 0, "w": 0, "3": 0, "4": 0}, ["shift", "control", "option"]),  # T+Q
]

# Right-hand keys NOT in workspace set that need guards
GUARD_KEYS = [
    "quote", "open_bracket", "close_bracket",
    "hyphen", "equal_sign", "backslash",
]

# Variable names for mode keys used in workspace operations
MODE_VARS = ["e", "r", "w", "3", "4", "q"]


def make_condition(name, value):
    return {"name": name, "type": "variable_if", "value": value}


def get_cond(conditions, name):
    for c in conditions:
        if c.get("name") == name:
            return c.get("value")
    return None


def make_action_manipulator(key_code, shell_cmd, mode_conds, extra_modifiers=None):
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
    conditions.append(make_condition("g_is_held", 0))

    # Encode operation mode in modifier flags so the eventtap can decode
    # the mode directly from the key event, without relying on async IPC.
    modifiers = ["fn"] + (extra_modifiers or [])

    return {
        "conditions": conditions,
        "from": {
            "key_code": key_code,
            "modifiers": {"optional": ["any"]},
        },
        "to": [
            {"key_code": key_code, "modifiers": modifiers},
            {"shell_command": shell_cmd},
        ],
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


HS_BIN = "/usr/local/bin/hs"
GRID_CMD_TEMPLATE = HS_BIN + " -c \"require('ws_grid').key{}('{}')\" &"


def make_grid_shell_command(key, direction):
    """Create a shell_command dict for ws_grid keyDown/keyUp."""
    return {"shell_command": GRID_CMD_TEMPLATE.format(direction, key)}


def make_t_w_setter():
    """W mode setter: when caps is held, pressing w sets w_is_held=1."""
    return {
        "conditions": [
            make_condition("caps_lock_is_held", 1),
        ],
        "from": {
            "key_code": "w",
            "modifiers": {"optional": ["any"]},
        },
        "to": [
            {"set_variable": {"name": "w_is_held", "value": 1}},
            make_grid_shell_command("w", "Down"),
        ],
        "to_after_key_up": [
            {"set_variable": {"name": "w_is_held", "value": 0}},
            make_grid_shell_command("w", "Up"),
        ],
        "type": "basic",
    }


def make_t_q_setter():
    """Q mode setter: when caps is held, pressing q sets q_is_held=1."""
    return {
        "conditions": [
            make_condition("caps_lock_is_held", 1),
        ],
        "from": {
            "key_code": "q",
            "modifiers": {"optional": ["any"]},
        },
        "to": [
            {"set_variable": {"name": "q_is_held", "value": 1}},
            make_grid_shell_command("q", "Down"),
        ],
        "to_after_key_up": [
            {"set_variable": {"name": "q_is_held", "value": 0}},
            make_grid_shell_command("q", "Up"),
        ],
        "type": "basic",
    }


def generate():
    ws_bin = "$HOME/.local/bin/ws.sh"
    actions = []

    for op_name, mode_conds, extra_mods in OPERATIONS:
        for display_name, key_code, ws_arg in WORKSPACE_KEYS:
            shell_cmd = f"{ws_bin} {op_name} {ws_arg}"
            actions.append(
                make_action_manipulator(key_code, shell_cmd, mode_conds, extra_mods)
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

    # T+Q guards: block non-workspace keys when Q is held in T layer
    q_guards = [
        make_guard_manipulator(kc, [("q_is_held", 1)], "t-ws-guard")
        for kc in GUARD_KEYS
    ]

    return {
        "t_w_setter": make_t_w_setter(),
        "t_q_setter": make_t_q_setter(),
        "actions": actions,
        "guards": e_guards + w_guards + q_guards,
    }


# --- Detection functions ---

def is_t_w_setter(m):
    """Match W setter (key=w, caps=1, sets w_is_held)."""
    conds = m.get("conditions", [])
    kc = m.get("from", {}).get("key_code", "")
    to = m.get("to", [{}])[0]
    sv = to.get("set_variable", {})
    return (kc == "w"
            and get_cond(conds, "caps_lock_is_held") == 1
            and sv.get("name") == "w_is_held")


def is_t_q_setter(m):
    """Match Q setter (key=q, caps=1, sets q_is_held)."""
    conds = m.get("conditions", [])
    kc = m.get("from", {}).get("key_code", "")
    to = m.get("to", [{}])[0]
    sv = to.get("set_variable", {})
    return (kc == "q"
            and get_cond(conds, "caps_lock_is_held") == 1
            and sv.get("name") == "q_is_held")


def is_old_q_noop(m):
    """Match old Q noop (key=q, caps=1, to vk_none)."""
    kc = m.get("from", {}).get("key_code", "")
    to = m.get("to", [{}])[0]
    return (kc == "q"
            and to.get("key_code") == "vk_none"
            and get_cond(m.get("conditions", []), "caps_lock_is_held") == 1)


_WORKSPACE_KEY_CODES = {kc for _, kc, _ in WORKSPACE_KEYS}


def is_t_ws_action(m):
    """Match T layer workspace action (t=1, has shell_command with ws.sh, workspace key)."""
    conds = m.get("conditions", [])
    kc = m.get("from", {}).get("key_code", "")
    if (get_cond(conds, "t_is_held") != 1
            or "to_after_key_up" in m
            or kc not in _WORKSPACE_KEY_CODES):
        return False
    # Check ALL to events for ws.sh (shell_command may be in to[0] or to[1])
    return any("ws.sh" in ev.get("shell_command", "") for ev in m.get("to", []))


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
    # Skip workspace actions (ws.sh shell commands) — check ALL to events
    if any("ws.sh" in ev.get("shell_command", "") for ev in m.get("to", [])):
        return False
    # Skip workspace guards
    if is_t_ws_guard(m):
        return False
    return True


MODE_KEY_SETTERS = [
    ("e", "e_is_held"),
    ("r", "r_is_held"),
    ("3", "3_is_held"),
    ("4", "4_is_held"),
    ("q", "q_is_held"),
]


def find_setter(manips, key_code, var_name):
    """Find a setter manipulator (caps=1, key_code, sets var_name)."""
    for i, m in enumerate(manips):
        conds = m.get("conditions", [])
        kc = m.get("from", {}).get("key_code", "")
        to = m.get("to", [{}])[0]
        sv = to.get("set_variable", {})
        if (kc == key_code
                and get_cond(conds, "caps_lock_is_held") == 1
                and sv.get("name") == var_name):
            return i
    return -1


def remove_ws_submode_from_setters(manips):
    """Remove any leftover ws_submode variables from E, R, 3, 4 setters."""
    for key_code, var_name in MODE_KEY_SETTERS:
        idx = find_setter(manips, key_code, var_name)
        if idx == -1:
            continue
        m = manips[idx]
        for field in ("to", "to_after_key_up"):
            items = m.get(field, [])
            m[field] = [
                item for item in items
                if item.get("set_variable", {}).get("name") != "ws_submode"
            ]


GRID_KEY_SETTERS = [("t", "t_is_held")] + MODE_KEY_SETTERS


def add_grid_shell_commands_to_setters(manips):
    """Add ws_grid keyDown/keyUp shell commands to T, E, R, 3, 4, Q setters."""
    for key_code, var_name in GRID_KEY_SETTERS:
        idx = find_setter(manips, key_code, var_name)
        if idx == -1:
            continue
        m = manips[idx]
        for field, direction in [("to", "Down"), ("to_after_key_up", "Up")]:
            items = m.get(field, [])
            # Remove any existing grid shell commands or key events (idempotent)
            items = [
                item for item in items
                if "ws_grid" not in item.get("shell_command", "")
                and not (item.get("key_code") == key_code and "fn" in item.get("modifiers", []))
            ]
            # Append grid command
            items.append(make_grid_shell_command(key_code, direction))
            m[field] = items


def find_t_e_setter(manips):
    """Find E setter (key=e, caps=1, sets e_is_held)."""
    for i, m in enumerate(manips):
        conds = m.get("conditions", [])
        kc = m.get("from", {}).get("key_code", "")
        to = m.get("to", [{}])[0]
        sv = to.get("set_variable", {})
        if (kc == "e"
                and get_cond(conds, "caps_lock_is_held") == 1
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
    removed = {"setters": 0, "actions": 0, "guards": 0, "q_noop": 0}
    for i in range(len(manips) - 1, -1, -1):
        m = manips[i]
        if is_t_w_setter(m) or is_t_q_setter(m):
            manips.pop(i)
            removed["setters"] += 1
        elif is_t_ws_action(m):
            manips.pop(i)
            removed["actions"] += 1
        elif is_t_ws_guard(m):
            manips.pop(i)
            removed["guards"] += 1
        elif is_old_q_noop(m):
            manips.pop(i)
            removed["q_noop"] += 1

    print(f"Removed: {removed['setters']} setters, {removed['actions']} actions, "
          f"{removed['guards']} guards, {removed['q_noop']} q_noop")

    # Phase 2: Add 3_is_held=0, 4_is_held=0, q_is_held=0 to all T layer manipulators
    new_mode_vars = ["3_is_held", "4_is_held", "q_is_held"]
    search_names = {"w_is_held", "3_is_held", "4_is_held", "q_is_held"}
    vars_added = {v: 0 for v in new_mode_vars}
    for m in manips:
        if is_t_layer_manipulator(m):
            conds = m["conditions"]
            for var_name in new_mode_vars:
                if get_cond(conds, var_name) is None:
                    # Insert after the last mode variable present
                    insert_after = "w_is_held"
                    for c in conds:
                        if c.get("name") in search_names:
                            insert_after = c.get("name")
                    for j, c in enumerate(conds):
                        if c.get("name") == insert_after:
                            conds.insert(j + 1, make_condition(var_name, 0))
                            vars_added[var_name] += 1
                            break
    for var_name, count in vars_added.items():
        print(f"Added {var_name}=0 to {count} T layer manipulators")

    # Phase 2b: Clean up any leftover ws_submode from setters
    remove_ws_submode_from_setters(manips)

    # Phase 2c: Add ws_grid shell commands to E, R, 3, 4, Q setters
    add_grid_shell_commands_to_setters(manips)
    print("Added ws_grid shell commands to T, E, R, 3, 4, Q setters")

    # Phase 3: Insert T+W and T+Q setters after T+E setter
    te_idx = find_t_e_setter(manips)
    if te_idx == -1:
        print("ERROR: Could not find T+E setter", file=sys.stderr)
        sys.exit(1)

    manips.insert(te_idx + 1, generated["t_q_setter"])
    manips.insert(te_idx + 1, generated["t_w_setter"])
    print("Inserted T+W and T+Q setters after T+E setter")

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
