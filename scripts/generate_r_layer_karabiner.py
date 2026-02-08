#!/usr/bin/env python3
"""Generate Karabiner-Elements manipulators for the R layer (workspace management).

Outputs JSON fragments for:
  1. Mode setters (R+E, R+W, R+Q)
  2. R layer setter (caps → sets r_is_held)
  3. Action manipulators (20 keys × N operations)
  4. Guard/noop manipulators for unmapped keys in R layer
"""

import json
import sys

# 20 workspace keys and their Karabiner key_codes
WORKSPACE_KEYS = [
    ("6", "6"),
    ("7", "7"),
    ("8", "8"),
    ("9", "9"),
    ("0", "0"),
    ("y", "y"),
    ("u", "u"),
    ("i", "i"),
    ("o", "o"),
    ("p", "p"),
    ("h", "h"),
    ("j", "j"),
    ("k", "k"),
    ("l", "l"),
    (";", "semicolon"),
    ("n", "n"),
    ("m", "m"),
    (",", "comma"),
    (".", "period"),
    ("/", "slash"),
]

# Operations: (name, karabiner_modifiers, r_val, e_val, w_val, q_val)
# Most specific (most positive conditions) first for Karabiner priority
OPERATIONS = [
    # R+E: focus display 2 → alt+shift (most specific first)
    ("focus-2", ["option", "shift"], 1, 1, 0, 0),
    # R only: focus display 1 → ctrl+shift
    ("focus-1", ["control", "shift"], 1, 0, 0, 0),
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

# Left-hand keys that aren't mode keys (r, e, w, q) and need guards
GUARD_LEFT_KEYS = [
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


def make_action_manipulator(key_code, modifiers, r_val, e_val, w_val, q_val):
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
        make_condition("q_is_held", q_val),
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
        "r_layer_setter": make_r_layer_setter(),
        "actions": [],
        "guards": [],
    }

    # Generate action manipulators (N operations × 20 keys)
    for op_name, modifiers, r_val, e_val, w_val, q_val in OPERATIONS:
        for _display, key_code in WORKSPACE_KEYS:
            result["actions"].append(
                make_action_manipulator(key_code, modifiers, r_val, e_val, w_val, q_val)
            )

    # Generate guard manipulators
    for key_code in GUARD_RIGHT_KEYS + GUARD_LEFT_KEYS:
        result["guards"].append(make_guard_manipulator(key_code))

    return result


if __name__ == "__main__":
    data = generate()
    json.dump(data, sys.stdout, indent=2)
    print()
