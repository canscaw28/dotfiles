#!/usr/bin/env python3
"""Generate physical key trackers and caps-*-physical setters for all layer keys.

Auto-detects layer keys from karabiner.json by finding manipulators with
caps_lock_is_held=1 that set *_is_held=1 and have to_after_key_up.

For each detected layer key, generates:
  1. A physical tracker (at END of manipulators) -- unconditional fallback that
     sets *_physical=1 and passes the key through. On key_up, resets *_physical
     and *_is_held, and stops key_suppress for that specific key.
  2. A caps-*-physical setter (after re-press caps setter, before unconditional) --
     when *_physical=1, pressing caps activates the layer and starts key_suppress
     for that specific key only.

Suppression is targeted: only the layer key(s) physically held before caps are
suppressed, leaving all other key repeats (e.g., caps+H arrow repeat) untouched.

Idempotent: removes old generated content before inserting new.
"""

import json
import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KARABINER_PATH = os.path.join(SCRIPT_DIR, "..", "karabiner", "karabiner.json")

HS_BIN = "/usr/local/bin/hs"


def detect_layer_keys(manips):
    """Auto-detect layer keys from existing setters in karabiner.json.

    Finds manipulators with caps_lock_is_held=1 condition, to_after_key_up,
    and first to event setting *_is_held=1. Extracts ws_grid status and
    extra to events (e.g., F's Ctrl+0).

    Returns list of (key_code, var_name, has_ws_grid, extra_to_events).
    """
    layer_keys = []
    for m in manips:
        # Skip generated content (avoid circular detection)
        desc = m.get("description", "")
        if desc.endswith("-physical-tracker"):
            continue
        if desc.startswith("caps-") and desc.endswith("-physical"):
            continue

        # Must have caps_lock_is_held=1 condition
        conds = m.get("conditions", [])
        if not any(c.get("name") == "caps_lock_is_held" and c.get("value") == 1
                   for c in conds):
            continue

        # Must have to_after_key_up (distinguishes setters from actions)
        if "to_after_key_up" not in m:
            continue

        # First to event must set *_is_held=1
        to = m.get("to", [])
        if not to:
            continue
        first_sv = to[0].get("set_variable", {})
        var_name = first_sv.get("name", "")
        if not var_name.endswith("_is_held") or first_sv.get("value") != 1:
            continue

        key_code = m.get("from", {}).get("key_code", "")
        if not key_code:
            continue

        # Detect ws_grid in to events
        has_ws_grid = any("ws_grid" in ev.get("shell_command", "")
                         for ev in to)

        # Extract extra to events (skip set_variable and ws_grid shell commands)
        extra_to = []
        for ev in to[1:]:
            if "set_variable" in ev:
                continue
            if "ws_grid" in ev.get("shell_command", ""):
                continue
            if "key_suppress" in ev.get("shell_command", ""):
                continue
            extra_to.append(ev)

        layer_keys.append((key_code, var_name, has_ws_grid, extra_to))

    return layer_keys


def make_physical_tracker(key_code, var_name, has_ws_grid):
    """Create a physical tracker manipulator for a layer key.

    Placed at END of manipulators as an unconditional fallback. When the key
    is pressed without caps, this fires (the caps-conditional setter above
    won't match). Sets *_physical=1 and passes the key through.
    """
    physical_var = f"{key_code}_physical"

    if has_ws_grid:
        up_cmd = (f'{HS_BIN} -c "require(\'key_suppress\').stop(\'{key_code}\');'
                  f" require('ws_grid').keyUp('{key_code}')\" &")
    else:
        up_cmd = f'{HS_BIN} -c "require(\'key_suppress\').stop(\'{key_code}\')" &'

    return {
        "description": f"{key_code}-physical-tracker",
        "from": {
            "key_code": key_code,
            "modifiers": {"optional": ["any"]},
        },
        "to": [
            {"set_variable": {"name": physical_var, "value": 1}},
            {"key_code": key_code},
        ],
        "to_after_key_up": [
            {"set_variable": {"name": physical_var, "value": 0}},
            {"set_variable": {"name": var_name, "value": 0}},
            {"shell_command": up_cmd},
        ],
        "type": "basic",
    }


def make_caps_physical_setter(key_code, var_name, has_ws_grid, extra_to):
    """Create a caps-*-physical setter.

    When *_physical=1 (key already held), pressing caps activates
    caps_lock + the layer and starts key_suppress.
    """
    physical_var = f"{key_code}_physical"

    to = [
        {"set_variable": {"name": "caps_lock_is_held", "value": 1}},
        {"set_variable": {"name": "caps_lock_pressed", "value": 1}},
        {"set_variable": {"name": var_name, "value": 1}},
    ]
    to.extend(extra_to)

    if has_ws_grid:
        down_cmd = (f'{HS_BIN} -c "require(\'key_suppress\').start(\'{key_code}\');'
                    f" require('ws_grid').keyDown('{key_code}')\" &")
    else:
        down_cmd = f'{HS_BIN} -c "require(\'key_suppress\').start(\'{key_code}\')" &'
    to.append({"shell_command": down_cmd})

    reset_cmd = (f'{HS_BIN} -c "require(\'key_suppress\').stop();'
                 " require('ws_grid').resetAllKeys()\" &")

    return {
        "conditions": [
            {"name": physical_var, "type": "variable_if", "value": 1},
        ],
        "description": f"caps-{key_code}-physical",
        "from": {
            "key_code": "caps_lock",
            "modifiers": {"optional": ["any"]},
        },
        "to": to,
        "to_after_key_up": [
            {"set_variable": {"name": "caps_lock_is_held", "value": 0}},
            {"shell_command": reset_cmd},
        ],
        "to_delayed_action": {
            "to_if_canceled": [
                {"set_variable": {"name": "caps_lock_pressed", "value": 0}},
            ],
            "to_if_invoked": [
                {"set_variable": {"name": "caps_lock_pressed", "value": 0}},
            ],
        },
        "type": "basic",
    }


def is_generated_tracker(m):
    """Match a generated physical tracker by description pattern."""
    desc = m.get("description", "")
    return desc.endswith("-physical-tracker")


def is_generated_caps_physical(m):
    """Match a generated caps-*-physical setter by description pattern."""
    desc = m.get("description", "")
    return desc.startswith("caps-") and desc.endswith("-physical")


def find_repress_caps_setter(manips):
    """Find the re-press caps setter (caps_lock_pressed=1 condition)."""
    for i, m in enumerate(manips):
        if m.get("from", {}).get("key_code") != "caps_lock":
            continue
        for c in m.get("conditions", []):
            if c.get("name") == "caps_lock_pressed" and c.get("value") == 1:
                return i
    return -1


def find_unconditional_caps_setter(manips):
    """Find the unconditional caps setter (no conditions, sets caps_lock_pressed)."""
    for i, m in enumerate(manips):
        if m.get("from", {}).get("key_code") != "caps_lock":
            continue
        if m.get("conditions"):
            continue
        # Unconditional caps_lock manipulator
        return i
    return -1


def remove_key_suppress_start(m):
    """Remove key_suppress.start() from a caps setter's to array. Returns True if removed."""
    to = m.get("to", [])
    removed = False
    for i in range(len(to) - 1, -1, -1):
        sc = to[i].get("shell_command", "")
        if "key_suppress" in sc and "start" in sc:
            to.pop(i)
            removed = True
    return removed


def ensure_key_suppress_stop(m):
    """Ensure key_suppress.stop() is in a caps setter's to_after_key_up. Returns True if changed."""
    up_items = m.get("to_after_key_up", [])
    for ev in up_items:
        if "key_suppress" in ev.get("shell_command", "") and "stop" in ev.get("shell_command", ""):
            return False
    # Merge into existing resetAllKeys command if present
    for i, ev in enumerate(up_items):
        sc = ev.get("shell_command", "")
        if "resetAllKeys" in sc and "key_suppress" not in sc:
            up_items[i] = {
                "shell_command": (f'{HS_BIN} -c "require(\'key_suppress\').stop();'
                                  " require('ws_grid').resetAllKeys()\" &"),
            }
            return True
    # Otherwise append standalone stop
    up_items.append(
        {"shell_command": f'{HS_BIN} -c "require(\'key_suppress\').stop()" &'}
    )
    m["to_after_key_up"] = up_items
    return True


def main():
    with open(KARABINER_PATH) as f:
        config = json.load(f)

    manips = config["profiles"][0]["complex_modifications"]["rules"][0]["manipulators"]

    # Phase 1: Remove old generated content
    removed = {"trackers": 0, "caps_setters": 0}
    for i in range(len(manips) - 1, -1, -1):
        m = manips[i]
        if is_generated_tracker(m):
            manips.pop(i)
            removed["trackers"] += 1
        elif is_generated_caps_physical(m):
            manips.pop(i)
            removed["caps_setters"] += 1
    print(f"Removed: {removed['trackers']} trackers, {removed['caps_setters']} caps setters")

    # Phase 2: Auto-detect layer keys and generate trackers + caps setters
    layer_keys = detect_layer_keys(manips)
    print(f"Detected {len(layer_keys)} layer keys: {', '.join(k[0] for k in layer_keys)}")

    trackers = []
    caps_setters = []
    for key_code, var_name, has_ws_grid, extra_to in layer_keys:
        trackers.append(make_physical_tracker(key_code, var_name, has_ws_grid))
        caps_setters.append(make_caps_physical_setter(key_code, var_name, has_ws_grid, extra_to))

    # Phase 3: Insert caps setters after re-press caps setter
    repress_idx = find_repress_caps_setter(manips)
    if repress_idx == -1:
        print("ERROR: Could not find re-press caps setter", file=sys.stderr)
        sys.exit(1)

    for j, setter in enumerate(caps_setters):
        manips.insert(repress_idx + 1 + j, setter)
    print(f"Inserted {len(caps_setters)} caps-*-physical setters after re-press caps setter")

    # Phase 4: Append trackers at end of manipulators
    manips.extend(trackers)
    print(f"Appended {len(trackers)} physical trackers at end of manipulators")

    # Phase 5: Remove blanket key_suppress.start() from caps setters, ensure stop() remains
    repress_idx = find_repress_caps_setter(manips)
    if repress_idx != -1:
        if remove_key_suppress_start(manips[repress_idx]):
            print("Removed key_suppress.start() from re-press caps setter")
        if ensure_key_suppress_stop(manips[repress_idx]):
            print("Added key_suppress.stop() to re-press caps setter release")

    uncon_idx = find_unconditional_caps_setter(manips)
    if uncon_idx != -1:
        if remove_key_suppress_start(manips[uncon_idx]):
            print("Removed key_suppress.start() from unconditional caps setter")
        if ensure_key_suppress_stop(manips[uncon_idx]):
            print("Added key_suppress.stop() to unconditional caps setter release")

    # Write
    with open(KARABINER_PATH, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")

    print(f"\nDone! Total manipulators: {len(manips)}")


if __name__ == "__main__":
    main()
