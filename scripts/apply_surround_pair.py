#!/usr/bin/env python3
"""Add surround-pair manipulators to karabiner.json.

Activation: Caps+A+S sets surround_mode=1 and surround_oneshot=1.

Two usage modes:
  - Hold: Keep Caps+A+S held. Each supported key outputs open+close pair
    with cursor between. Caps release deactivates (resets surround_mode=0).
  - One-shot: Tap Caps+A+S, release everything. Next supported key fires
    surround pair and deactivates (resets surround_oneshot=0). A 5-second
    timeout cleans up surround_oneshot if unused.

Variables:
  - surround_mode: active during hold (caps_lock_is_held=1). Reset on caps release.
  - surround_oneshot: survives caps release. Reset by one-shot firing or 5s timeout.

Hold manipulators:    surround_mode=1 + caps_lock_is_held=1
One-shot manipulators: surround_oneshot=1 + caps_lock_is_held=0 + surround_mode=0

Idempotent: removes old surround components before inserting new ones.
"""

import json
import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KARABINER_PATH = os.path.join(SCRIPT_DIR, "..", "karabiner", "karabiner.json")
KARABINER_CLI = "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"

# Pair mappings: character -> (open, close)
PAIR_MAP = {
    "(": ("(", ")"),
    ")": ("(", ")"),
    "[": ("[", "]"),
    "]": ("[", "]"),
    "{": ("{", "}"),
    "}": ("{", "}"),
    "<": ("<", ">"),
    ">": ("<", ">"),
    "'": ("'", "'"),
    '"': ('"', '"'),
    "`": ("`", "`"),
    "*": ("*", "*"),
    "#": ("#", "#"),
}

# All supported keys: (key_code, shift_required, character)
# Only symbols — no letters or digits to avoid accidental triggers.
# IMPORTANT: Shifted variants MUST come before unshifted for the same key_code,
# because unshifted manipulators use optional:["any"] which matches shift too.
# Karabiner uses first-match priority, so shifted (mandatory:["shift"]) must
# be earlier in the array to match before the unshifted catch-all.
SURROUND_KEYS = []

# Shifted digits (symbols only) — no unshifted digits, so no ordering issue
SHIFTED_DIGIT_MAP = {
    "1": "!", "2": "@", "3": "#", "4": "$", "5": "%",
    "6": "^", "7": "&", "8": "*", "9": "(", "0": ")",
}
for digit, symbol in SHIFTED_DIGIT_MAP.items():
    SURROUND_KEYS.append((digit, True, symbol))

# Symbol keys: shifted first, then unshifted, grouped by key_code
SYMBOL_KEY_MAP = {
    "hyphen": "-",
    "equal_sign": "=",
    "open_bracket": "[",
    "close_bracket": "]",
    "backslash": "\\",
    "semicolon": ";",
    "quote": "'",
    "comma": ",",
    "period": ".",
    "slash": "/",
    "grave_accent_and_tilde": "`",
}

SHIFTED_SYMBOL_MAP = {
    "hyphen": ("_", True),
    "equal_sign": ("+", True),
    "open_bracket": ("{", True),
    "close_bracket": ("}", True),
    "backslash": ("|", True),
    "semicolon": (":", True),
    "quote": ('"', True),
    "comma": ("<", True),
    "period": (">", True),
    "slash": ("?", True),
    "grave_accent_and_tilde": ("~", True),
}

# Add shifted BEFORE unshifted for each key_code
for key_code, char in SYMBOL_KEY_MAP.items():
    if key_code in SHIFTED_SYMBOL_MAP:
        shifted_char, _ = SHIFTED_SYMBOL_MAP[key_code]
        SURROUND_KEYS.append((key_code, True, shifted_char))
    SURROUND_KEYS.append((key_code, False, char))

DESCRIPTION_PREFIX = "surround-pair"


def make_condition(name, value):
    return {"name": name, "type": "variable_if", "value": value}


HS_BIN = "/usr/local/bin/hs"


def escape_lua_char(char):
    """Escape a character for embedding in a Lua single-quoted string."""
    if char == "'":
        return "\\'"
    if char == "\\":
        return "\\\\"
    return char


def make_shell_command(char):
    """Create shell_command to call Hammerspoon surround_pair.fire()."""
    escaped = escape_lua_char(char)
    return {"shell_command": f"{HS_BIN} -c \"require('surround_pair').fire('{escaped}')\" &"}


def make_hold_manipulator(key_code, shift_required, char):
    """Hold mode: surround_mode=1 + caps_lock_is_held=1."""
    conditions = [
        make_condition("surround_mode", 1),
        make_condition("caps_lock_is_held", 1),
    ]

    from_event = {"key_code": key_code}
    if shift_required:
        from_event["modifiers"] = {"mandatory": ["shift"], "optional": ["any"]}
    else:
        from_event["modifiers"] = {"optional": ["any"]}

    return {
        "conditions": conditions,
        "description": f"{DESCRIPTION_PREFIX}: {char} (hold)",
        "from": from_event,
        "to": [
            {"set_variable": {"name": "surround_oneshot", "value": 0}},
            make_shell_command(char),
        ],
        "type": "basic",
    }


def make_oneshot_manipulator(key_code, shift_required, char):
    """One-shot mode: surround_oneshot=1 + caps_lock_is_held=0 + surround_mode=0."""
    conditions = [
        make_condition("surround_oneshot", 1),
        make_condition("caps_lock_is_held", 0),
        make_condition("surround_mode", 0),
    ]

    from_event = {"key_code": key_code}
    if shift_required:
        from_event["modifiers"] = {"mandatory": ["shift"], "optional": ["any"]}
    else:
        from_event["modifiers"] = {"optional": ["any"]}

    return {
        "conditions": conditions,
        "description": f"{DESCRIPTION_PREFIX}: {char} (oneshot)",
        "from": from_event,
        "to": [
            {"set_variable": {"name": "surround_oneshot", "value": 0}},
            make_shell_command(char),
        ],
        "type": "basic",
    }


def make_s_setter():
    """Create the A+S surround mode setter.

    Sets both surround_mode=1 (for hold) and surround_oneshot=1 (for one-shot).
    Launches a 5-second timeout to clean up surround_oneshot if unused.
    """
    timeout_cmd = (
        f'(sleep 5 && "{KARABINER_CLI}" '
        "--set-variables '{\"surround_oneshot\":0}') &"
    )
    return {
        "conditions": [
            make_condition("caps_lock_is_held", 1),
            make_condition("a_is_held", 1),
        ],
        "description": f"{DESCRIPTION_PREFIX}-setter",
        "from": {
            "key_code": "s",
            "modifiers": {"optional": ["any"]},
        },
        "to": [
            {"set_variable": {"name": "surround_mode", "value": 1}},
            {"set_variable": {"name": "surround_oneshot", "value": 1}},
            {"shell_command": timeout_cmd},
        ],
        "type": "basic",
    }


def is_surround_manipulator(m):
    """Detect surround-pair manipulators by description prefix."""
    return m.get("description", "").startswith(DESCRIPTION_PREFIX)


def generate():
    """Generate all surround-pair manipulators."""
    setter = make_s_setter()
    hold_actions = []
    oneshot_actions = []

    for key_code, shift_required, char in SURROUND_KEYS:
        hold_actions.append(make_hold_manipulator(key_code, shift_required, char))
        oneshot_actions.append(make_oneshot_manipulator(key_code, shift_required, char))

    return {"setter": setter, "hold_actions": hold_actions, "oneshot_actions": oneshot_actions}


def find_a_layer_end(manips):
    """Find the index after the last A layer manipulator."""
    last_a_idx = -1
    for i, m in enumerate(manips):
        conds = m.get("conditions", [])
        has_caps = any(c.get("name") == "caps_lock_is_held" and c.get("value") == 1 for c in conds)
        has_a = any(c.get("name") == "a_is_held" and c.get("value") == 1 for c in conds)
        has_other_layer = any(
            c.get("name") in ("f_is_held", "d_is_held", "t_is_held") and c.get("value") == 1
            for c in conds
        )
        if has_caps and has_a and not has_other_layer:
            last_a_idx = i
    return last_a_idx


def is_a_layer_action(m):
    """Match A layer actions (caps=1, a=1, no other layer, not a setter, not surround)."""
    if is_surround_manipulator(m):
        return False
    conds = m.get("conditions", [])
    has_caps = any(c.get("name") == "caps_lock_is_held" and c.get("value") == 1 for c in conds)
    has_a = any(c.get("name") == "a_is_held" and c.get("value") == 1 for c in conds)
    has_other_layer = any(
        c.get("name") in ("f_is_held", "d_is_held", "t_is_held") and c.get("value") == 1
        for c in conds
    )
    if not (has_caps and has_a and not has_other_layer):
        return False
    # Exclude setters (they have to_after_key_up with set_variable)
    if "to_after_key_up" in m:
        up = m["to_after_key_up"]
        if any(item.get("set_variable", {}).get("name", "").endswith("_is_held") for item in up):
            return False
    return True


def add_surround_exclusion_to_a_layer(manips):
    """Add surround_mode=0 condition to A layer actions to prevent mode bleed."""
    count = 0
    for m in manips:
        if not is_a_layer_action(m):
            continue
        conds = m["conditions"]
        # Skip if already has surround_mode condition
        if any(c.get("name") == "surround_mode" for c in conds):
            continue
        conds.append(make_condition("surround_mode", 0))
        count += 1
    return count


def add_surround_reset_to_caps_release(manips):
    """Add surround_mode=0 reset to caps_lock release handlers."""
    count = 0
    for m in manips:
        up_items = m.get("to_after_key_up", [])
        sets_caps_0 = any(
            item.get("set_variable", {}).get("name") == "caps_lock_is_held"
            and item.get("set_variable", {}).get("value") == 0
            for item in up_items
        )
        if not sets_caps_0:
            continue

        # Remove old surround resets (idempotent)
        up_items = [
            item for item in up_items
            if item.get("set_variable", {}).get("name") not in ("surround_mode", "surround_oneshot")
        ]
        up_items.append({"set_variable": {"name": "surround_mode", "value": 0}})
        m["to_after_key_up"] = up_items
        count += 1
    return count


def main():
    with open(KARABINER_PATH) as f:
        config = json.load(f)

    manips = config["profiles"][0]["complex_modifications"]["rules"][0]["manipulators"]
    generated = generate()

    # Phase 1: Remove old surround-pair components
    removed = 0
    for i in range(len(manips) - 1, -1, -1):
        if is_surround_manipulator(manips[i]):
            manips.pop(i)
            removed += 1
    print(f"Removed {removed} old surround-pair manipulators")

    # Phase 2: Find insertion point (after A layer)
    a_end = find_a_layer_end(manips)
    if a_end == -1:
        print("ERROR: Could not find A layer manipulators", file=sys.stderr)
        sys.exit(1)

    insert_pos = a_end + 1

    # Phase 3: Insert setter
    manips.insert(insert_pos, generated["setter"])
    print("Inserted surround-pair setter (A+S)")
    insert_pos += 1

    # Phase 4: Insert hold actions, then oneshot actions
    for j, action in enumerate(generated["hold_actions"]):
        manips.insert(insert_pos + j, action)
    print(f"Inserted {len(generated['hold_actions'])} hold manipulators")
    insert_pos += len(generated["hold_actions"])

    for j, action in enumerate(generated["oneshot_actions"]):
        manips.insert(insert_pos + j, action)
    print(f"Inserted {len(generated['oneshot_actions'])} oneshot manipulators")

    # Phase 5: Add surround_mode=0 exclusion to A layer actions
    a_count = add_surround_exclusion_to_a_layer(manips)
    print(f"Added surround_mode=0 to {a_count} A layer actions")

    # Phase 6: Add surround_mode=0 to caps release (hold mode cleanup)
    caps_count = add_surround_reset_to_caps_release(manips)
    print(f"Added surround_mode=0 reset to {caps_count} caps release handlers")

    # Write
    with open(KARABINER_PATH, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")

    print(f"\nDone! Total manipulators: {len(manips)}")


if __name__ == "__main__":
    main()
