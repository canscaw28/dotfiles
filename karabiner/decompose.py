#!/usr/bin/python3
"""Decompose karabiner.json into per-layer YAML source files.

One-time migration script. Reads the monolithic karabiner.json,
classifies manipulators by layer/function, and writes raw YAML
source files that build.py can reassemble identically.

Preserves exact manipulator ordering by splitting into sequential
files — when the category changes, a new file starts.

Usage:
    python3 decompose.py
"""

import json
import os

import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(SCRIPT_DIR, "src")
LAYERS_DIR = os.path.join(SRC_DIR, "layers")
INPUT_FILE = os.path.join(SCRIPT_DIR, "karabiner.json")


def get_positive_vars(m):
    return {
        c["name"]
        for c in m.get("conditions", [])
        if c.get("type") == "variable_if" and c.get("value") == 1
    }


def get_app_condition(m):
    for c in m.get("conditions", []):
        if c.get("type") == "frontmost_application_if":
            ids = c.get("bundle_identifiers", [])
            if ids:
                return ids[0]
    return None


def has_set_variable(m):
    for t in m.get("to", []):
        if "set_variable" in t:
            return True
    return False


def classify(i, m):
    """Classify a manipulator into a category name."""
    desc = m.get("description", "")
    pos = get_positive_vars(m)
    app = get_app_condition(m)
    has_key_up = "to_after_key_up" in m
    has_setvar = has_set_variable(m)
    to_json = json.dumps(m.get("to", []))
    from_key = m.get("from", {}).get("key_code", "")

    # Generated manipulators (by description pattern)
    if "physical-tracker" in desc:
        return "physical-trackers"
    if desc.startswith("caps-") and "physical" in desc:
        return "caps-physical"
    if desc == "t-ws-guard":
        return "t-ws-guards"
    if desc == "t-nav-action":
        return "t-nav"
    if desc.startswith("f-cursor-grid"):
        return "f-cursor-grid"
    if desc.startswith("f-vimium") or desc.startswith("f-homerow"):
        return "f-link-hints"
    if desc.startswith("F+D+S") or desc.startswith("F+S+D"):
        return "f-grid-setters"

    # A layer
    if "a_is_held" in pos and "caps_lock_is_held" in pos and len(pos) == 2:
        return "a-system"

    # G+D Chrome tab move
    if desc.startswith("G+D+"):
        return "g-chrome-tab-move"
    if desc.startswith("G+F+J") or desc.startswith("G+F+K"):
        return "g-chrome-tab-move"
    if desc.startswith("G+F+"):
        return "g-chrome-reorder"

    # G layer
    if "g_is_held" in pos:
        if app and "Chrome" in app:
            return "g-chrome"
        if app and "iterm" in app:
            return "g-iterm"
        return "g-generic"

    # T layer
    if "t_is_held" in pos:
        if "ws.sh" in to_json:
            return "t-ws-actions"
        return "t-direction"

    # F layer
    if "f_is_held" in pos:
        if has_setvar and has_key_up:
            return "layer-setters"
        return "f-scroll"

    # iTerm overrides
    if app and "iterm" in app:
        if "caps_lock_is_held" in pos:
            if "s_is_held" in pos:
                return "default-selection-iterm"
            if "d_is_held" in pos:
                return "default-deletion-iterm"
            return "default-iterm"
        return "iterm-commands"

    # Setters
    if has_setvar and has_key_up and "caps_lock_is_held" in pos:
        return "layer-setters"

    # Infrastructure
    if "caps_lock_pressed" in pos:
        return "infrastructure"
    if from_key == "non_us_backslash" and has_setvar:
        return "infrastructure"
    if from_key == "right_shift" and "caps_lock_is_held" in pos:
        return "infrastructure"

    # Default layer modes
    if "caps_lock_is_held" in pos:
        if "s_is_held" in pos:
            return "default-selection"
        if "d_is_held" in pos:
            return "default-deletion"
        return "default-cursor"

    return "unclassified"


def main():
    os.makedirs(LAYERS_DIR, exist_ok=True)

    with open(INPUT_FILE) as f:
        config = json.load(f)

    profile = config["profiles"][0]
    manips = profile["complex_modifications"]["rules"][0]["manipulators"]

    # Write profile metadata
    profile_meta = {
        "name": profile["name"],
        "selected": profile["selected"],
        "rule_description": profile["complex_modifications"]["rules"][0]["description"],
        "virtual_hid_keyboard": profile["virtual_hid_keyboard"],
        "simple_modifications": profile["simple_modifications"],
    }
    with open(os.path.join(SRC_DIR, "profile.yaml"), "w") as f:
        yaml.dump(profile_meta, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    # Walk through manipulators in order, splitting on category changes.
    # Each contiguous run of the same category becomes one file.
    segments = []  # [(category, [manipulators])]
    current_cat = None
    current_items = []

    for i, m in enumerate(manips):
        cat = classify(i, m)
        if cat != current_cat:
            if current_items:
                segments.append((current_cat, current_items))
            current_cat = cat
            current_items = [(i, m)]
        else:
            current_items.append((i, m))

    if current_items:
        segments.append((current_cat, current_items))

    # Assign filenames: use a sequence number prefix for ordering,
    # and a suffix if a category appears in multiple segments.
    cat_counts = {}
    file_segments = []

    for seg_idx, (cat, items) in enumerate(segments):
        cat_counts[cat] = cat_counts.get(cat, 0) + 1
        count = cat_counts[cat]
        # Use segment index for ordering prefix
        filename = f"{seg_idx:02d}-{cat}.yaml"
        file_segments.append((filename, cat, items))

    # Write files
    for filename, cat, items in file_segments:
        filepath = os.path.join(LAYERS_DIR, filename)
        data = {
            "raw": True,
            "manipulators": [m for _, m in items],
        }
        with open(filepath, "w") as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False,
                      width=200)
        print(f"  {filename}: {len(items)} manipulators (indices {items[0][0]}-{items[-1][0]})")

    # Write build order
    build_order = {
        "steps": [{"file": filename} for filename, _, _ in file_segments],
    }
    with open(os.path.join(SRC_DIR, "build_order.yaml"), "w") as f:
        yaml.dump(build_order, f, default_flow_style=False, sort_keys=False)

    total = sum(len(items) for _, _, items in file_segments)
    print(f"\nTotal: {total} manipulators across {len(file_segments)} files")


if __name__ == "__main__":
    main()
