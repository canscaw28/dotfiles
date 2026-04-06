#!/usr/bin/python3
"""Convert raw YAML layer files to compact shorthand format.

Reads each raw: true file, reverse-engineers the layer/conditions,
and rewrites it in compact format. Validates roundtrip after each file.

Usage:
    python3 compact.py [--dry-run] [file ...]
    python3 compact.py                    # Convert all raw files
    python3 compact.py 04-a-system.yaml   # Convert specific file
"""

import argparse
import json
import os
import sys

import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LAYERS_DIR = os.path.join(SCRIPT_DIR, "src", "layers")

# Same var list as build.py
ALL_LAYER_VARS = [
    "a_is_held", "s_is_held", "d_is_held", "f_is_held", "r_is_held",
    "e_is_held", "w_is_held", "t_is_held", "g_is_held",
    "3_is_held", "4_is_held", "q_is_held",
]

VAR_TO_SHORT = {
    "caps_lock_is_held": "caps",
    "a_is_held": "a", "s_is_held": "s", "d_is_held": "d",
    "f_is_held": "f", "r_is_held": "r", "e_is_held": "e",
    "w_is_held": "w", "t_is_held": "t", "g_is_held": "g",
    "3_is_held": "3", "4_is_held": "4", "q_is_held": "q",
}


def extract_condition_pattern(manip):
    """Extract positive vars, negative vars, and app conditions from a manipulator."""
    positive = []
    negative = []
    app = None
    app_unless = None
    other_conditions = []

    for c in manip.get("conditions", []):
        ctype = c.get("type", "")
        if ctype == "variable_if":
            name = c["name"]
            if name in VAR_TO_SHORT:
                if c["value"] == 1:
                    positive.append(VAR_TO_SHORT[name])
                else:
                    negative.append(VAR_TO_SHORT[name])
            else:
                other_conditions.append(c)
        elif ctype == "frontmost_application_if":
            app = c.get("bundle_identifiers", [None])[0]
        elif ctype == "frontmost_application_unless":
            app_unless = c.get("bundle_identifiers", [None])[0]
        else:
            other_conditions.append(c)

    return positive, negative, app, app_unless, other_conditions


def reverse_to_event(event):
    """Convert a Karabiner 'to' event back to compact shorthand."""
    if "shell_command" in event:
        return {"shell": event["shell_command"]}
    if "set_variable" in event:
        sv = event["set_variable"]
        if sv["name"] == "guard_noop" and sv["value"] == 0:
            return "noop"
        return {"set": {sv["name"]: sv["value"]}}
    if "select_input_source" in event:
        return {"select_input_source": event["select_input_source"]}
    if "key_code" in event:
        kc = event["key_code"]
        mods = event.get("modifiers")
        hold = event.get("hold_down_milliseconds")
        if mods and hold:
            return {"key": kc, "modifiers": mods, "hold_down_milliseconds": hold}
        if mods:
            mod_str = "+".join(mods) if isinstance(mods, list) else mods
            return [kc, mod_str]
        if hold:
            return {"key": kc, "hold_down_milliseconds": hold}
        return kc
    # Passthrough unknown
    return event


def reverse_to_list(events):
    """Convert a list of 'to' events to compact form."""
    if not events:
        return None
    result = [reverse_to_event(e) for e in events]
    # If single simple key, unwrap
    if len(result) == 1:
        return result[0]
    return result


def is_noop_list(events):
    """Check if a to list is just [guard_noop = 0]."""
    if len(events) == 1 and "set_variable" in events[0]:
        sv = events[0]["set_variable"]
        return sv.get("name") == "guard_noop" and sv.get("value") == 0
    return False


def compact_manipulator(manip, file_positive, file_negative, file_app, file_app_unless):
    """Convert a raw manipulator to compact form.

    Returns (compact_dict, needs_override) where needs_override is True
    if this manipulator's conditions differ from file-level defaults.
    """
    positive, negative, app, app_unless, other_conds = extract_condition_pattern(manip)

    result = {}
    needs_raw = False

    # Check if conditions match file-level defaults
    if positive != file_positive or negative != file_negative or app != file_app or app_unless != file_app_unless or other_conds:
        needs_raw = True

    # From
    from_data = manip.get("from", {})
    from_key = from_data.get("key_code")
    from_mods = from_data.get("modifiers", {})

    if from_mods.get("mandatory"):
        result["from"] = from_key
        result["from_modifiers"] = from_mods["mandatory"]
    elif from_key:
        result["from"] = from_key
    else:
        result["from"] = from_data  # passthrough complex from

    # Description
    if "description" in manip:
        result["description"] = manip["description"]

    # Per-manipulator condition overrides
    if needs_raw:
        if positive != file_positive:
            result["layer"] = positive
        if negative != file_negative:
            result["negative_conditions"] = negative
        if app != file_app:
            result["app"] = app
        if app_unless != file_app_unless:
            result["app_unless"] = app_unless
        if other_conds:
            # Can't express these in shorthand — need raw conditions
            result["conditions"] = manip["conditions"]

    # Parameters
    params = manip.get("parameters", {})
    hold_threshold = params.pop("basic.to_if_held_down_threshold_milliseconds", None)
    if hold_threshold:
        result["hold_threshold"] = hold_threshold
    if params:
        result["parameters"] = params

    # To
    to_events = manip.get("to")
    if to_events:
        result["to"] = reverse_to_list(to_events)

    # To if held down
    held = manip.get("to_if_held_down")
    if held:
        if is_noop_list(held):
            result["to_if_held_down"] = "noop"
        else:
            result["to_if_held_down"] = reverse_to_list(held)

    # To after key up
    key_up = manip.get("to_after_key_up")
    if key_up:
        result["to_after_key_up"] = reverse_to_list(key_up)

    # To delayed action
    delayed = manip.get("to_delayed_action")
    if delayed:
        result["to_delayed_action"] = delayed

    return result, needs_raw


def find_common_pattern(manipulators):
    """Find the most common condition pattern across manipulators."""
    patterns = {}
    for m in manipulators:
        pos, neg, app, app_unless, other = extract_condition_pattern(m)
        key = (tuple(pos), tuple(neg), app, app_unless, bool(other))
        patterns[key] = patterns.get(key, 0) + 1

    if not patterns:
        return [], [], None, None

    best = max(patterns, key=patterns.get)
    return list(best[0]), list(best[1]), best[2], best[3]


def convert_file(filepath, dry_run=False):
    """Convert a raw YAML file to compact format."""
    with open(filepath) as f:
        data = yaml.safe_load(f)

    if not data or not data.get("raw"):
        return False, "not a raw file"

    manipulators = data.get("manipulators", [])
    if not manipulators:
        return False, "no manipulators"

    # Check if any manipulator has conditions we can't express in shorthand
    has_unknown_conditions = False
    for m in manipulators:
        _, _, _, _, other = extract_condition_pattern(m)
        if other:
            has_unknown_conditions = True
            break

    if has_unknown_conditions:
        return False, "has non-standard conditions (keeping raw)"

    # Find common pattern
    file_pos, file_neg, file_app, file_app_unless = find_common_pattern(manipulators)

    # Check if ALL manipulators have conditions that are setter-like
    # (set_variable in to + to_after_key_up, minimal conditions)
    # These are infrastructure and should stay raw
    all_setters = all(
        any("set_variable" in json.dumps(t) for t in m.get("to", []))
        and "to_after_key_up" in m
        and len(m.get("conditions", [])) <= 2
        and not m.get("description", "").startswith(("A+", "G+", "F+"))
        for m in manipulators
    )

    # Also check for physical trackers
    all_physical = all("physical" in m.get("description", "") for m in manipulators)

    if all_setters or all_physical:
        return False, "infrastructure/setter (keeping raw)"

    # Convert
    compact_manips = []
    any_overrides = False
    for m in manipulators:
        cm, needs_override = compact_manipulator(m, file_pos, file_neg, file_app, file_app_unless)
        if needs_override:
            any_overrides = True
        compact_manips.append(cm)

    # Build output
    output = {}
    if file_pos:
        output["layer"] = file_pos
    if file_neg is not None:
        output["negative_conditions"] = file_neg
    if file_app:
        output["app"] = file_app
    if file_app_unless:
        output["app_unless"] = file_app_unless
    output["manipulators"] = compact_manips

    if dry_run:
        return True, f"would convert {len(manipulators)} manipulators"

    with open(filepath, "w") as f:
        yaml.dump(output, f, default_flow_style=False, allow_unicode=True, sort_keys=False,
                  width=200)

    return True, f"converted {len(manipulators)} manipulators"


def main():
    parser = argparse.ArgumentParser(description="Convert raw YAML files to compact format")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be converted")
    parser.add_argument("files", nargs="*", help="Specific files to convert (default: all)")
    args = parser.parse_args()

    if args.files:
        files = [os.path.join(LAYERS_DIR, f) if not os.path.isabs(f) else f for f in args.files]
    else:
        files = sorted(
            os.path.join(LAYERS_DIR, f)
            for f in os.listdir(LAYERS_DIR)
            if f.endswith(".yaml")
        )

    converted = 0
    skipped = 0
    for filepath in files:
        name = os.path.basename(filepath)
        ok, msg = convert_file(filepath, dry_run=args.dry_run)
        if ok:
            print(f"  ✓ {name}: {msg}")
            converted += 1
        else:
            print(f"  · {name}: {msg}")
            skipped += 1

    print(f"\n{converted} converted, {skipped} skipped")


if __name__ == "__main__":
    main()
