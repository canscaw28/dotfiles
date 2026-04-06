#!/usr/bin/python3
"""Build karabiner.json from YAML source files.

Reads compact per-layer YAML files from src/layers/, expands shorthand
into full Karabiner Elements JSON, and writes the final karabiner.json.

Usage:
    python3 build.py              # Build and write karabiner.json
    python3 build.py --check      # Build to temp, exit 1 if different from existing
    python3 build.py --diff       # Build to temp, show diff
    python3 build.py --output F   # Write to a specific file
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile

import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(SCRIPT_DIR, "src")
LAYERS_DIR = os.path.join(SRC_DIR, "layers")
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "karabiner.json")

# ── Condition inference ────────────────────────────────────────────────

# All layer/mode variable names known to the system.
# When a manipulator declares layer: [caps, g], the builder sets
# caps_lock_is_held=1, g_is_held=1, and every other key in this list to 0.
ALL_LAYER_VARS = [
    "a_is_held",
    "s_is_held",
    "d_is_held",
    "f_is_held",
    "r_is_held",
    "e_is_held",
    "w_is_held",
    "t_is_held",
    "g_is_held",
    "3_is_held",
    "4_is_held",
    "q_is_held",
]

# Map short names used in layer: [...] to variable names
VAR_MAP = {
    "caps": "caps_lock_is_held",
    "a": "a_is_held",
    "s": "s_is_held",
    "d": "d_is_held",
    "f": "f_is_held",
    "r": "r_is_held",
    "e": "e_is_held",
    "w": "w_is_held",
    "t": "t_is_held",
    "g": "g_is_held",
    "3": "3_is_held",
    "4": "4_is_held",
    "q": "q_is_held",
}


def build_conditions(file_ctx, manip):
    """Build the conditions array for a manipulator.

    Uses the file-level 'layer' and per-manipulator overrides.
    """
    # Per-manipulator conditions override takes full control
    if "conditions" in manip:
        return manip["conditions"]

    layer = manip.get("layer", file_ctx.get("layer"))
    if layer is None:
        return []

    # Collect which variables are explicitly positive
    positive = {}
    for name in layer:
        var = VAR_MAP.get(name)
        if var:
            positive[var] = 1

    # Build negative conditions: everything in ALL_LAYER_VARS not in positive
    # unless negatives are explicitly listed
    negatives = manip.get("negative_conditions", file_ctx.get("negative_conditions"))

    conditions = []

    # Always put caps_lock_is_held first if present
    if "caps_lock_is_held" in positive:
        conditions.append({"name": "caps_lock_is_held", "type": "variable_if", "value": 1})

    # Add negative conditions
    if negatives is not None:
        # Explicit list of variables to negate
        for var_short in negatives:
            var = VAR_MAP.get(var_short, var_short)
            if var not in positive:
                conditions.append({"name": var, "type": "variable_if", "value": 0})
    else:
        # Default: negate all layer vars not in positive
        for var in ALL_LAYER_VARS:
            if var not in positive:
                conditions.append({"name": var, "type": "variable_if", "value": 0})

    # Add positive layer vars (except caps which is already added)
    for var, val in positive.items():
        if var != "caps_lock_is_held":
            conditions.append({"name": var, "type": "variable_if", "value": val})

    # App conditions
    app = manip.get("app", file_ctx.get("app"))
    if app:
        conditions.append({
            "bundle_identifiers": [app],
            "type": "frontmost_application_if",
        })

    app_unless = manip.get("app_unless", file_ctx.get("app_unless"))
    if app_unless:
        conditions.append({
            "bundle_identifiers": [app_unless],
            "type": "frontmost_application_unless",
        })

    return conditions


# ── Shorthand expansion ───────────────────────────────────────────────

def expand_key(val):
    """Expand a shorthand key spec into Karabiner JSON.

    Accepts:
        "h"                     -> {"key_code": "h"}
        ["h", "shift"]          -> {"key_code": "h", "modifiers": ["shift"]}
        ["h", "command+shift"]  -> {"key_code": "h", "modifiers": ["command", "shift"]}
        {"key_code": ...}       -> passthrough
        {"shell": "..."}        -> {"shell_command": "..."}
        {"set": {"name": v}}    -> {"set_variable": {"name": "name", "value": v}}
        "noop"                  -> {"set_variable": {"name": "guard_noop", "value": 0}}
    """
    if isinstance(val, dict):
        # Already full JSON or special forms
        if "shell" in val:
            return {"shell_command": val["shell"]}
        if "set" in val:
            d = val["set"]
            name = list(d.keys())[0]
            return {"set_variable": {"name": name, "value": d[name]}}
        if "key" in val:
            result = {"key_code": val["key"]}
            if "modifiers" in val:
                result["modifiers"] = val["modifiers"]
            if "hold_down_milliseconds" in val:
                result["hold_down_milliseconds"] = val["hold_down_milliseconds"]
            return result
        if "select_input_source" in val:
            return val
        # Passthrough for already-formed JSON
        return val

    if val == "noop":
        return {"set_variable": {"name": "guard_noop", "value": 0}}

    if isinstance(val, str):
        return {"key_code": val}

    if isinstance(val, list) and len(val) == 2:
        key, mods = val
        if isinstance(mods, str):
            mods = mods.split("+")
        return {"key_code": key, "modifiers": mods}

    return val


def expand_to(val):
    """Expand a 'to' field which can be a single item or list."""
    if val is None:
        return None
    if isinstance(val, list):
        # Could be a single [key, modifier] pair or a list of events
        if len(val) == 2 and isinstance(val[0], str) and isinstance(val[1], str):
            # Single key+modifier pair
            return [expand_key(val)]
        return [expand_key(item) for item in val]
    return [expand_key(val)]


def expand_manipulator(file_ctx, manip):
    """Expand a compact YAML manipulator into full Karabiner JSON."""
    result = {}

    # Conditions
    conditions = build_conditions(file_ctx, manip)
    if conditions:
        result["conditions"] = conditions

    # Description
    if "description" in manip:
        result["description"] = manip["description"]

    # From
    from_key = manip.get("from")
    if isinstance(from_key, str):
        result["from"] = {
            "key_code": from_key,
            "modifiers": {"optional": ["any"]},
        }
        if "from_modifiers" in manip:
            result["from"] = {
                "key_code": from_key,
                "modifiers": {"mandatory": manip["from_modifiers"]},
            }
    elif isinstance(from_key, dict):
        result["from"] = from_key
    else:
        result["from"] = from_key

    # Parameters
    params = {}
    if "hold_threshold" in manip:
        params["basic.to_if_held_down_threshold_milliseconds"] = manip["hold_threshold"]
    if "parameters" in manip:
        params.update(manip["parameters"])
    if params:
        result["parameters"] = params

    # To events
    to = expand_to(manip.get("to"))
    if to is not None:
        result["to"] = to

    # To if held down
    if "to_if_held_down" in manip:
        held = manip["to_if_held_down"]
        if held == "noop":
            result["to_if_held_down"] = [{"set_variable": {"name": "guard_noop", "value": 0}}]
        else:
            result["to_if_held_down"] = expand_to(held)

    # To after key up
    if "to_after_key_up" in manip:
        result["to_after_key_up"] = expand_to(manip["to_after_key_up"])

    # To delayed action
    if "to_delayed_action" in manip:
        result["to_delayed_action"] = manip["to_delayed_action"]

    result["type"] = "basic"

    return result


# ── File loading ──────────────────────────────────────────────────────

def load_layer_file(filepath):
    """Load a YAML layer file and expand all manipulators."""
    with open(filepath) as f:
        data = yaml.safe_load(f)

    if data is None or "manipulators" not in data:
        return []

    is_raw = data.get("raw", False)

    if is_raw:
        # Raw mode: manipulators are already full Karabiner JSON
        return data["manipulators"]

    # Build file-level context for condition inference
    file_ctx = {}
    for key in ("layer", "app", "app_unless", "negative_conditions"):
        if key in data:
            file_ctx[key] = data[key]

    result = []
    for manip in data["manipulators"]:
        result.append(expand_manipulator(file_ctx, manip))

    return result


# ── Build ─────────────────────────────────────────────────────────────

def build(verbose=False):
    """Build the complete karabiner.json structure."""
    # Load profile metadata
    profile_path = os.path.join(SRC_DIR, "profile.yaml")
    with open(profile_path) as f:
        profile_meta = yaml.safe_load(f)

    # Load build order
    order_path = os.path.join(SRC_DIR, "build_order.yaml")
    with open(order_path) as f:
        build_order = yaml.safe_load(f)

    all_manipulators = []

    for step in build_order["steps"]:
        if "generate" in step:
            gen_path = os.path.join(SRC_DIR, step["generate"])
            if verbose:
                print(f"Running generator: {step['generate']}")
            subprocess.check_call([sys.executable, gen_path], cwd=SCRIPT_DIR)
            continue

        filepath = os.path.join(LAYERS_DIR, step["file"])
        if not os.path.exists(filepath):
            print(f"WARNING: {filepath} not found, skipping", file=sys.stderr)
            continue

        manipulators = load_layer_file(filepath)
        if verbose:
            print(f"  {step['file']}: {len(manipulators)} manipulators")
        all_manipulators.extend(manipulators)

    if verbose:
        print(f"Total: {len(all_manipulators)} manipulators")

    # Assemble the full config
    config = {
        "profiles": [
            {
                "complex_modifications": {
                    "rules": [
                        {
                            "description": profile_meta.get(
                                "rule_description",
                                "Hold Caps Lock as a modifier for navigation and editing",
                            ),
                            "manipulators": all_manipulators,
                        }
                    ]
                },
                "name": profile_meta.get("name", "Default profile"),
                "selected": profile_meta.get("selected", True),
                "virtual_hid_keyboard": profile_meta.get("virtual_hid_keyboard", {}),
                "simple_modifications": profile_meta.get("simple_modifications", []),
            }
        ]
    }

    return config


def write_config(config, output_path):
    """Write config as JSON matching Karabiner's formatting."""
    with open(output_path, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write("\n")


def main():
    parser = argparse.ArgumentParser(description="Build karabiner.json from YAML sources")
    parser.add_argument("--check", action="store_true", help="Verify output matches existing file")
    parser.add_argument("--diff", action="store_true", help="Show diff without writing")
    parser.add_argument("--output", help="Write to specific file")
    parser.add_argument("--verbose", "-v", action="store_true", help="Print per-file stats")
    args = parser.parse_args()

    config = build(verbose=args.verbose)

    if args.check or args.diff:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as tmp:
            json.dump(config, tmp, indent=2, ensure_ascii=False)
            tmp.write("\n")
            tmp_path = tmp.name

        try:
            result = subprocess.run(
                ["diff", "-u", OUTPUT_FILE, tmp_path],
                capture_output=True, text=True,
            )
            if result.returncode != 0:
                if args.diff:
                    print(result.stdout)
                else:
                    print("MISMATCH: built config differs from existing karabiner.json",
                          file=sys.stderr)
                    print(result.stdout[:2000], file=sys.stderr)
                sys.exit(1)
            else:
                if args.verbose:
                    print("OK: output matches existing karabiner.json")
        finally:
            os.unlink(tmp_path)
    else:
        output_path = args.output or OUTPUT_FILE
        write_config(config, output_path)
        if args.verbose:
            print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
