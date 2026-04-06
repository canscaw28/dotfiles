#!/usr/bin/python3
"""Consolidate split YAML files using a manual priority spec.

Defines the target file structure as a list of groups. Each group merges
multiple files into one, and the new build_order respects first-match
priority by placing app-conditional files before generic ones.

Strategy:
  - iTerm overrides come BEFORE default layer files (so app match wins)
  - All files of the same category merge into one
  - Build order is rebuilt from scratch from the target spec

Usage:
    python3 consolidate.py
"""

import json
import os
import subprocess
import sys

import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(SCRIPT_DIR, "src")
LAYERS_DIR = os.path.join(SRC_DIR, "layers")
BUILD_ORDER = os.path.join(SRC_DIR, "build_order.yaml")


# Target build order. Each entry is either:
#   - "filename.yaml" (single file, kept as-is)
#   - {"merge_into": "newname.yaml", "from": ["a.yaml", "b.yaml"]}
#     (merge multiple files into one new file)
TARGET_ORDER = [
    "00-infrastructure.yaml",
    "01-caps-physical.yaml",
    "02-infrastructure.yaml",
    "03-layer-setters.yaml",
    "04-a-system.yaml",
    "05-f-grid-setters.yaml",
    "06-layer-setters.yaml",
    "07-g-chrome-tab-move.yaml",
    # iTerm-specific (non-caps) commands
    "10-iterm-commands.yaml",
    # iTerm caps overrides — kept separate due to different negative conditions,
    # but both must come BEFORE default-cursor so iTerm-specific matches win
    "09-default-iterm.yaml",
    "11-default-iterm.yaml",
    {
        "merge_into": "08-default-cursor.yaml",
        "from": ["08-default-cursor.yaml", "12-default-cursor.yaml", "35-default-cursor.yaml"],
    },
    "14-default-selection-iterm.yaml",
    "16-default-selection-iterm.yaml",
    {
        "merge_into": "13-default-selection.yaml",
        "from": ["13-default-selection.yaml", "15-default-selection.yaml", "17-default-selection.yaml"],
    },
    # Default deletion files have inconsistent app conditions; keep separate
    "18-default-deletion.yaml",
    "19-default-deletion-iterm.yaml",
    "20-default-deletion.yaml",
    "21-default-deletion-iterm.yaml",
    "22-default-deletion.yaml",
    "24-f-link-hints.yaml",
    "45-f-cursor-grid.yaml",
    "26-f-scroll.yaml",
    "27-t-ws-actions.yaml",
    "28-t-nav.yaml",
    "29-t-ws-guards.yaml",
    # T direction files — keep separate for now since the quote-key ws-actions
    # are interleaved between them
    "30-t-direction.yaml",
    "31-t-ws-actions.yaml",
    "32-t-direction.yaml",
    "33-t-ws-actions.yaml",
    "34-t-direction.yaml",
    "36-g-iterm.yaml",
    {
        "merge_into": "16-g-chrome.yaml",
        "from": ["37-g-chrome.yaml", "39-g-chrome.yaml"],
    },
    {
        "merge_into": "17-g-generic.yaml",
        "from": ["38-g-generic.yaml", "40-g-generic.yaml", "42-g-generic.yaml"],
    },
    "41-g-chrome-reorder.yaml",
    "43-t-direction.yaml",
    "44-physical-trackers.yaml",
]


def load_yaml(path):
    with open(path) as f:
        return yaml.safe_load(f)


def write_yaml(path, data):
    with open(path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False, width=200)


def file_signature(data):
    return (
        tuple(data.get("layer", [])) if data.get("layer") else None,
        tuple(data.get("negative_conditions", [])) if "negative_conditions" in data else None,
        data.get("app"),
        data.get("app_unless"),
        bool(data.get("raw", False)),
    )


def semantic_check(target_path):
    tmp_path = "/tmp/consolidate_test.json"
    result = subprocess.run(
        ["/usr/bin/python3", os.path.join(SCRIPT_DIR, "build.py"), "--output", tmp_path],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return False, f"build failed: {result.stderr}"

    with open(target_path) as f:
        original = json.load(f)
    with open(tmp_path) as f:
        rebuilt = json.load(f)

    orig = original["profiles"][0]["complex_modifications"]["rules"][0]["manipulators"]
    new = rebuilt["profiles"][0]["complex_modifications"]["rules"][0]["manipulators"]

    def signature(m):
        return (
            m.get("description", ""),
            json.dumps(m.get("from", {}), sort_keys=True),
            json.dumps(m.get("to", []), sort_keys=True),
            json.dumps(m.get("to_after_key_up", []), sort_keys=True),
        )

    orig_sigs = sorted(signature(m) for m in orig)
    new_sigs = sorted(signature(m) for m in new)

    if orig_sigs != new_sigs:
        missing = set(orig_sigs) - set(new_sigs)
        extra = set(new_sigs) - set(orig_sigs)
        return False, f"missing={len(missing)}, extra={len(extra)}"

    return True, "OK"


def merge_files(merge_into, from_files):
    """Merge from_files into merge_into. All must share the same file-level signature."""
    paths = [os.path.join(LAYERS_DIR, f) for f in from_files]
    datas = [load_yaml(p) for p in paths]

    sig0 = file_signature(datas[0])
    for f, d in zip(from_files[1:], datas[1:]):
        if file_signature(d) != sig0:
            return False, f"{f} has different file-level conditions"

    # Build merged data
    merged = dict(datas[0])
    all_manips = []
    for d in datas:
        all_manips.extend(d.get("manipulators", []))
    merged["manipulators"] = all_manips

    target_path = os.path.join(LAYERS_DIR, merge_into)

    # Delete source files first (if any of them == merge_into, save its content)
    for p in paths:
        if os.path.exists(p) and p != target_path:
            os.unlink(p)

    write_yaml(target_path, merged)
    return True, f"merged {len(from_files)} files ({len(all_manips)} manipulators)"


def main():
    karabiner_path = os.path.join(SCRIPT_DIR, "karabiner.json")

    ok, msg = semantic_check(karabiner_path)
    if not ok:
        print(f"ERROR: build is broken before consolidation: {msg}")
        sys.exit(1)

    print("Consolidating files...")

    # Process merges
    new_steps = []
    for entry in TARGET_ORDER:
        if isinstance(entry, str):
            new_steps.append({"file": entry})
            continue

        merge_into = entry["merge_into"]
        from_files = entry["from"]
        ok, msg = merge_files(merge_into, from_files)
        print(f"  {merge_into}: {msg}")
        if not ok:
            print(f"FAILED: {msg}")
            sys.exit(1)
        new_steps.append({"file": merge_into})

    # Write new build order
    with open(BUILD_ORDER, "w") as f:
        yaml.dump({"steps": new_steps}, f, default_flow_style=False, sort_keys=False)

    # Verify
    ok, msg = semantic_check(karabiner_path)
    if not ok:
        print(f"\nERROR: semantic check failed after consolidation: {msg}")
        sys.exit(1)
    print("\nSemantic check: OK")

    # Now build the new karabiner.json
    print("Building new karabiner.json...")
    subprocess.check_call(
        ["/usr/bin/python3", os.path.join(SCRIPT_DIR, "build.py")],
    )
    print(f"Done. New file count: {len(os.listdir(LAYERS_DIR))}")


if __name__ == "__main__":
    main()
