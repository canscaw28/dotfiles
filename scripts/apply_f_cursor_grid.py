#!/usr/bin/python3
"""
Generate F layer cursor grid YAML source file.

Modes:
  F+D (8x8)  — grid-based cursor movement
  F+S (32x32) — fine grid-based cursor movement
  F+D+S      — fixed-position jumps (edges, corners, quadrant centers)
               Activated by holding F+D+S together (D and S setters in
               05-f-grid-setters.yaml swap modes when both held).
  F+P        — toggle 8x8 move grid overlay (no D/S/E)
  F+D+P      — toggle 8x8 move grid overlay
  F+S+P      — toggle 32x32 move grid overlay
  F+D+S+P    — toggle 8x8 jump grid overlay
  F+;        — left mouse click (vanilla F layer)
  F+'        — right mouse click (vanilla F layer)

Output: karabiner/src/layers/45-f-cursor-grid.yaml

This script writes YAML source files only. It does NOT modify
karabiner.json directly. Run `./reload.sh --karabiner` after
running this script to rebuild the JSON config.
"""

import os
import sys

import yaml

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_FILE = os.path.join(REPO_ROOT, "karabiner", "src", "layers", "f-cursor-grid.yaml")

# (key_code, direction, amount). amount<0 means "jump to edge"
MOVE_KEYS = [
    ("h", "left", 1),
    ("j", "down", 1),
    ("k", "up", 1),
    ("l", "right", 1),
    ("y", "left", -1),
    ("o", "right", -1),
    ("u", "left", 2),
    ("i", "right", 2),
    ("n", "down", -1),
    ("period", "up", -1),
    ("m", "down", 2),
    ("comma", "up", 2),
]

# Fixed-position jump keys for F+D+S mode
JUMP_KEYS = [
    "h", "j", "k", "l", "slash",  # slash is window center
    "y", "o", "n", "period",
    "u", "i", "m", "comma",
]


def hs(snippet):
    return f'/usr/local/bin/hs -c "{snippet}" 2>/dev/null &'


def move_manipulator(key, direction, amount, mode_key, grid_size):
    return {
        "from": key,
        "description": f"f-cursor-grid: F+{mode_key.upper()}+{key} {direction} {amount}",
        "to": {"shell": hs(f"require('cursor_grid').startMove('{direction}', {amount}, {grid_size})")},
        "to_after_key_up": {"shell": hs("require('cursor_grid').stopMove()")},
    }


def jump_manipulator(key):
    label = "jump center" if key == "slash" else "jump"
    return {
        "from": key,
        "description": f"f-cursor-grid: F+D+S+{key} {label}",
        "to": {"shell": hs(f"require('cursor_grid').jump('{key}')")},
    }


def main():
    # Build the structure
    output = {
        "_generated_by": "scripts/apply_f_cursor_grid.py",
        "_warning": "Auto-generated. Do not edit directly. Run scripts/apply_f_cursor_grid.py to regenerate.",
    }

    # The file has multiple sections with different layer requirements.
    # Use a list of "blocks" — each block has its own layer/negatives + manipulators.
    blocks = []

    # Block 1: F+D movement
    d_manips = [move_manipulator(k, d, a, "d", 8) for k, d, a in MOVE_KEYS]
    # Block 2: F+S movement
    s_manips = [move_manipulator(k, d, a, "s", 32) for k, d, a in MOVE_KEYS]
    # Block 3: F+D+S jumps (the file-level layer)
    jump_manips = [jump_manipulator(k) for k in JUMP_KEYS]

    # Click manipulators (F+; and F+')
    click_manips = [
        {
            "from": "semicolon",
            "description": "f-cursor-grid: F+semicolon left click",
            "layer": ["caps", "f"],
            "negative_conditions": ["e", "g", "t"],
            "to": {"shell": hs("hs.eventtap.leftClick(hs.mouse.absolutePosition()); require('cursor_grid').flashClick()")},
        },
        {
            "from": "quote",
            "description": "f-cursor-grid: F+quote right click",
            "layer": ["caps", "f"],
            "negative_conditions": ["e", "g", "t"],
            "to": {"shell": hs("hs.eventtap.rightClick(hs.mouse.absolutePosition()); require('cursor_grid').flashClick()")},
        },
    ]

    # Toggle manipulators
    toggle_manips = [
        {
            "from": "p",
            "description": "f-cursor-grid: F+P toggle grid",
            "layer": ["caps", "f"],
            "negative_conditions": ["d", "s", "e", "g", "t"],
            "to": {"shell": hs("require('cursor_grid').toggleGrid(8, 'move')")},
        },
        {
            "from": "p",
            "description": "f-cursor-grid: F+D+P toggle grid",
            "layer": ["caps", "f", "d"],
            "negative_conditions": ["g", "t", "s"],
            "to": {"shell": hs("require('cursor_grid').toggleGrid(8, 'move')")},
        },
        {
            "from": "p",
            "description": "f-cursor-grid: F+S+P toggle grid",
            "layer": ["caps", "f", "s"],
            "negative_conditions": ["g", "t", "d"],
            "to": {"shell": hs("require('cursor_grid').toggleGrid(32, 'move')")},
        },
        {
            "from": "p",
            "description": "f-cursor-grid: F+D+S+P toggle grid",
            "to": {"shell": hs("require('cursor_grid').toggleGrid(8, 'jump')")},
        },
    ]

    # All movement (F+D and F+S) uses per-manipulator layer overrides
    # The file-level layer is F+D+S (the jumps)
    # Movement manipulators need their own layer specs
    for m in d_manips:
        m["layer"] = ["caps", "f", "d"]
        m["negative_conditions"] = ["g", "t"]
    for m in s_manips:
        m["layer"] = ["caps", "f", "s"]
        m["negative_conditions"] = ["g", "t"]

    output["layer"] = ["caps", "f", "d", "s"]
    output["negative_conditions"] = ["g", "t"]
    output["manipulators"] = d_manips + s_manips + jump_manips + click_manips + toggle_manips

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w") as f:
        yaml.dump(output, f, default_flow_style=False, allow_unicode=True, sort_keys=False, width=200)

    print(f"Wrote {len(output['manipulators'])} cursor grid manipulators to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
