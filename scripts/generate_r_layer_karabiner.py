#!/usr/bin/env python3
"""Generate Karabiner-Elements manipulators for the R layer (workspace management).

Outputs JSON fragments for:
  1. R+E mode setter (caps + r → sets e_is_held)
  2. R+W mode setter (caps + r → sets w_is_held)
  3. R layer setter (caps → sets r_is_held)
  4. 60 action manipulators (20 keys × 3 operations)
  5. Guard/noop manipulators for unmapped keys in R layer
"""

import json
import sys

# 20 workspace keys and their Karabiner key_codes
WORKSPACE_KEYS = [
    # Row 1: numbers (monitor 1)
    ("6", "6"),
    ("7", "7"),
    ("8", "8"),
    ("9", "9"),
    ("0", "0"),
    # Row 2: letters (monitor 1)
    ("y", "y"),
    ("u", "u"),
    ("i", "i"),
    ("o", "o"),
    ("p", "p"),
    # Row 3: letters + semicolon (monitor 2, fallback 1)
    ("h", "h"),
    ("j", "j"),
    ("k", "k"),
    ("l", "l"),
    (";", "semicolon"),
    # Row 4: letters + symbols (monitor 2, fallback 1)
    ("n", "n"),
    ("m", "m"),
    (",", "comma"),
    (".", "period"),
    ("/", "slash"),
]

# Operations: (name, modifiers_list, conditions for r/e/w)
# Each tuple: (description, karabiner_modifiers, r_val, e_val, w_val)
OPERATIONS = [
    # R+E+W: move + follow → ctrl+alt+shift (most specific first)
    ("move+follow", ["control", "option", "shift"], 1, 1, 1),
    # R+E: move window (stay) → cmd+ctrl+shift
    ("move", ["command", "control", "shift"], 1, 1, 0),
    # R only: switch workspace → ctrl+shift
    ("switch", ["control", "shift"], 1, 0, 0),
]

# Right-hand keys NOT in workspace set that need guards
GUARD_RIGHT_KEYS = [
    "quote",
    "open_bracket",
    "close_bracket",
    "hyphen",
    "equal_sign",
    "backslash",
]

# Left-hand keys that aren't mode keys (r, e) and need guards
# W is guarded because it only activates as a sub-mode of R+E
GUARD_LEFT_KEYS = [
    "w",
    "q",
    "a",
    "s",
    "d",
    "f",
    "g",
    "z",
    "x",
    "c",
    "v",
    "b",
]


def make_condition(name, value):
    return {"name": name, "type": "variable_if", "value": value}


def make_action_manipulator(key_code, modifiers, r_val, e_val, w_val):
    """Create an action manipulator for R layer workspace operation."""
    conditions = [
        make_condition("caps_lock_is_held", 1),
        make_condition("a_is_held", 0),
        make_condition("s_is_held", 0),
        make_condition("d_is_held", 0),
        make_condition("f_is_held", 0),
        make_condition("r_is_held", r_val),
        make_condition("e_is_held", e_val),
        make_condition("w_is_held", w_val),
        make_condition("t_is_held", 0),
        make_condition("g_is_held", 0),
    ]

    return {
        "conditions": conditions,
        "from": {
            "key_code": key_code,
            "modifiers": {"optional": ["any"]},
        },
        "to": [
            {
                "key_code": key_code,
                "modifiers": modifiers,
            }
        ],
        "type": "basic",
    }


def make_guard_manipulator(key_code):
    """Create a guard/noop manipulator for R layer."""
    conditions = [
        make_condition("caps_lock_is_held", 1),
        make_condition("r_is_held", 1),
        make_condition("t_is_held", 0),
    ]

    return {
        "conditions": conditions,
        "from": {
            "key_code": key_code,
            "modifiers": {"optional": ["any"]},
        },
        "to": [{"set_variable": {"name": "guard_noop", "value": 0}}],
        "type": "basic",
    }


def make_r_w_setter():
    """R+E+W mode setter: when r+e held, pressing w sets w_is_held=1."""
    return {
        "conditions": [
            make_condition("caps_lock_is_held", 1),
            make_condition("r_is_held", 1),
            make_condition("e_is_held", 1),
        ],
        "from": {
            "key_code": "w",
            "modifiers": {"optional": ["any"]},
        },
        "to": [{"set_variable": {"name": "w_is_held", "value": 1}}],
        "to_after_key_up": [{"set_variable": {"name": "w_is_held", "value": 0}}],
        "type": "basic",
    }


def make_r_e_setter():
    """R+E mode setter: when r_is_held=1, pressing e sets e_is_held=1."""
    return {
        "conditions": [
            make_condition("caps_lock_is_held", 1),
            make_condition("r_is_held", 1),
        ],
        "from": {
            "key_code": "e",
            "modifiers": {"optional": ["any"]},
        },
        "to": [{"set_variable": {"name": "e_is_held", "value": 1}}],
        "to_after_key_up": [{"set_variable": {"name": "e_is_held", "value": 0}}],
        "type": "basic",
    }


def make_r_layer_setter():
    """R layer setter: when caps_lock_is_held=1, pressing r sets r_is_held=1."""
    return {
        "conditions": [
            make_condition("caps_lock_is_held", 1),
        ],
        "from": {
            "key_code": "r",
            "modifiers": {"optional": ["any"]},
        },
        "to": [{"set_variable": {"name": "r_is_held", "value": 1}}],
        "to_after_key_up": [{"set_variable": {"name": "r_is_held", "value": 0}}],
        "type": "basic",
    }


def generate():
    result = {
        "r_e_setter": make_r_e_setter(),
        "r_w_setter": make_r_w_setter(),
        "r_layer_setter": make_r_layer_setter(),
        "actions": [],
        "guards": [],
    }

    # Generate 60 action manipulators (3 operations × 20 keys)
    for op_name, modifiers, r_val, e_val, w_val in OPERATIONS:
        for _display, key_code in WORKSPACE_KEYS:
            result["actions"].append(
                make_action_manipulator(key_code, modifiers, r_val, e_val, w_val)
            )

    # Generate guard manipulators
    for key_code in GUARD_RIGHT_KEYS + GUARD_LEFT_KEYS:
        result["guards"].append(make_guard_manipulator(key_code))

    return result


if __name__ == "__main__":
    data = generate()
    json.dump(data, sys.stdout, indent=2)
    print()
