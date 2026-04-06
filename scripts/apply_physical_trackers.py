#!/usr/bin/python3
"""Generate physical key trackers and caps-*-physical setters as YAML.

For each layer key, generates:
  1. A physical tracker (in 44-physical-trackers.yaml) — unconditional fallback
     that sets *_physical=1 and passes the key through. On key_up, resets
     *_physical and *_is_held, and runs the per-key cleanup commands.
  2. A caps-*-physical setter (in 01-caps-physical.yaml) — when *_physical=1,
     pressing caps activates the layer and starts key_suppress.

Layer key configuration is hardcoded below. To add a new layer key, add an
entry to LAYER_KEYS and re-run this script.

This script writes YAML source files only. It does NOT modify karabiner.json.
Run `./reload.sh --karabiner` after running this script to rebuild.
"""

import os

import yaml

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRACKERS_FILE = os.path.join(REPO_ROOT, "karabiner", "src", "layers", "44-physical-trackers.yaml")
CAPS_PHYSICAL_FILE = os.path.join(REPO_ROOT, "karabiner", "src", "layers", "01-caps-physical.yaml")

HS = "/usr/local/bin/hs"

# Layer key configuration. For each key, declare:
#   key:           the key code that activates the layer
#   key_up_extras: extra commands to run when the key is released (after key_suppress.stop)
#   key_down_extras: extra commands to run when caps activates the layer (after key_suppress.start)
LAYER_KEYS = [
    {"key": "a", "key_up_extras": [], "key_down_extras": []},
    {"key": "s", "key_up_extras": ["require('cursor_grid').modeKeyUp('s')"], "key_down_extras": []},
    {"key": "d", "key_up_extras": ["require('cursor_grid').modeKeyUp('d')"], "key_down_extras": []},
    {"key": "f", "key_up_extras": ["require('cursor_grid').modeReset()"], "key_down_extras": [],
     "pre_shell_events": [{"key_code": "0", "modifiers": ["control"]}]},
    {"key": "r", "key_up_extras": ["require('ws_grid').keyUp('r')"], "key_down_extras": ["require('ws_grid').keyDown('r')"]},
    {"key": "e", "key_up_extras": ["require('ws_grid').keyUp('e')", "require('cursor_grid').modeReset()"], "key_down_extras": ["require('ws_grid').keyDown('e')"]},
    {"key": "w", "key_up_extras": ["require('ws_grid').keyUp('w')"], "key_down_extras": ["require('ws_grid').keyDown('w')"]},
    {"key": "4", "key_up_extras": ["require('ws_grid').keyUp('4')"], "key_down_extras": ["require('ws_grid').keyDown('4')"]},
    {"key": "3", "key_up_extras": ["require('ws_grid').keyUp('3')"], "key_down_extras": ["require('ws_grid').keyDown('3')"]},
    {"key": "t", "key_up_extras": ["require('ws_grid').keyUp('t')"], "key_down_extras": ["require('ws_grid').keyDown('t')", "require('focus_border').flash()"]},
    {"key": "g", "key_up_extras": [], "key_down_extras": ["require('focus_border').flash()"]},
]


def hs_cmd(snippet):
    return f'{HS} -c "{snippet}" &'


def make_physical_tracker(spec):
    key = spec["key"]
    parts = [f"require('key_suppress').stop('{key}')"] + spec["key_up_extras"]
    up_cmd = hs_cmd("; ".join(parts))

    return {
        "description": f"{key}-physical-tracker",
        "from": {
            "key_code": key,
            "modifiers": {"optional": ["any"]},
        },
        "to": [
            {"set_variable": {"name": f"{key}_physical", "value": 1}},
            {"key_code": key},
        ],
        "to_after_key_up": [
            {"set_variable": {"name": f"{key}_physical", "value": 0}},
            {"set_variable": {"name": f"{key}_is_held", "value": 0}},
            {"shell_command": up_cmd},
        ],
        "type": "basic",
    }


def make_caps_physical_setter(spec):
    key = spec["key"]
    parts = [f"require('key_suppress').start('{key}')"] + spec["key_down_extras"]
    down_cmd = hs_cmd("; ".join(parts))
    reset_cmd = hs_cmd("require('key_suppress').stop(); require('ws_grid').resetAllKeys(); require('cursor_grid').modeReset()")

    to_events = [
        {"set_variable": {"name": "caps_lock_is_held", "value": 1}},
        {"set_variable": {"name": "caps_lock_pressed", "value": 1}},
        {"set_variable": {"name": f"{key}_is_held", "value": 1}},
    ]
    # Insert any pre-shell key events (e.g. F's Ctrl+0 for cursor grid)
    for ev in spec.get("pre_shell_events", []):
        to_events.append(ev)
    to_events.append({"shell_command": down_cmd})

    return {
        "conditions": [
            {"name": f"{key}_physical", "type": "variable_if", "value": 1},
        ],
        "description": f"caps-{key}-physical",
        "from": {
            "key_code": "non_us_backslash",
            "modifiers": {"optional": ["any"]},
        },
        "to": to_events,
        "to_after_key_up": [
            {"set_variable": {"name": "caps_lock_is_held", "value": 0}},
            {"set_variable": {"name": "caps_lock_pressed", "value": 0}},
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


def write_yaml(filepath, manipulators):
    output = {
        "_generated_by": "scripts/apply_physical_trackers.py",
        "_warning": "Auto-generated. Do not edit directly.",
        "raw": True,
        "manipulators": manipulators,
    }
    with open(filepath, "w") as f:
        yaml.dump(output, f, default_flow_style=False, allow_unicode=True, sort_keys=False, width=200)


def main():
    trackers = [make_physical_tracker(spec) for spec in LAYER_KEYS]
    caps_setters = [make_caps_physical_setter(spec) for spec in LAYER_KEYS]

    write_yaml(TRACKERS_FILE, trackers)
    write_yaml(CAPS_PHYSICAL_FILE, caps_setters)

    print(f"Wrote {len(trackers)} physical trackers to {TRACKERS_FILE}")
    print(f"Wrote {len(caps_setters)} caps-physical setters to {CAPS_PHYSICAL_FILE}")
    print(f"Layer keys: {', '.join(s['key'] for s in LAYER_KEYS)}")


if __name__ == "__main__":
    main()
