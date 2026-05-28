#!/usr/bin/python3
"""Generate help_data.json for the on-screen hotkey help overlay.

README.md is the single source of truth for documented keybindings. This parses
its per-layer sections and tables into structured JSON consumed by
.hammerspoon/help_overlay.lua, so the overlay can never drift from the docs.

Run standalone, from build.py's build(), or via reload.sh --karabiner.

    python3 build_help.py            # write help_data.json
    python3 build_help.py --check    # exit 1 if the file is stale
"""

import argparse
import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
README = os.path.join(SCRIPT_DIR, "README.md")
OUTPUT = os.path.normpath(
    os.path.join(SCRIPT_DIR, os.pardir, ".hammerspoon", "help_data.json")
)

# "## Default Layer (⇪)" -> default; "## Aerospace Layer (⇪+T)" -> T.
# The (⇪…) marker is what separates the 7 real layers from prose sections
# like "Modes" or "MacBook Keyboard Ghosting".
LAYER_HEADER_RE = re.compile(r"^##\s+(.*?)\s*\(⇪(?:\s*\+\s*([A-Za-z0-9]))?\)\s*$")
SUBHEADER_RE = re.compile(r"^(#{3,4})\s+(.*?)\s*$")
# Layers-table key cell: "⇪ + F" -> F, "⇪" -> default
LAYERS_TABLE_KEY_RE = re.compile(r"⇪(?:\s*\+\s*([A-Za-z0-9]))?")


def split_row(line):
    """Split a markdown table row into trimmed cells, honoring escaped pipes."""
    inner = line.strip()
    inner = inner.strip("|")
    cells = re.split(r"(?<!\\)\|", inner)
    return [c.strip().replace("\\|", "|") for c in cells]


def is_separator(line):
    return bool(re.match(r"^\|?\s*:?-{3,}", line.strip()))


def strip_emphasis(text):
    return text.replace("*", "").replace("`", "").strip()


# Physical QWERTY order, left→right then top→bottom. Rows within a section are
# sorted by the trigger key's position here so the overlay can be scanned by
# location: 6 7 8 9 0 - =  before  y u i o p [ ] \  before  h j k l ; '  etc.
PHYS_ORDER = "`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./"
SHIFT_TO_BASE = {
    "~": "`", "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6",
    "&": "7", "*": "8", "(": "9", ")": "0", "_": "-", "+": "=", "{": "[",
    "}": "]", "|": "\\", ":": ";", '"': "'", "<": ",", ">": ".", "?": "/",
}


def phys_rank(keys):
    """Sort key for a binding row: the physical position of its trigger key.
    Non-single-key triggers (e.g. '⌘ + Z', '*key*') sort to the end, stably."""
    m = re.search(r"\]\s*\+\s*(.+)$", keys)
    tok = (m.group(1) if m else keys).strip().strip("*").strip()
    if len(tok) != 1:
        return len(PHYS_ORDER)
    ch = SHIFT_TO_BASE.get(tok, tok.lower())
    idx = PHYS_ORDER.find(ch)
    return idx if idx >= 0 else len(PHYS_ORDER)


def row_is_empty(cols):
    """A row with nothing but blanks or an '*available*' marker carries no binding."""
    joined = strip_emphasis(" ".join(cols)).lower()
    return joined == "" or joined == "available"


def parse():
    with open(README) as f:
        lines = f.readlines()

    layers = {}          # key -> {name, key, sections: [...]}
    index = []           # [{key, name, domain}] from the Layers table
    order = []           # layer keys in document order

    cur_layer = None     # key of the layer currently being parsed
    cur_h3 = None
    cur_h4 = None
    in_layers_table = False  # parsing the top-level "## Layers" table

    i = 0
    n = len(lines)
    while i < n:
        line = lines[i].rstrip("\n")

        m = LAYER_HEADER_RE.match(line)
        if m:
            name, key = m.group(1), (m.group(2) or "default")
            key = key.upper() if key != "default" else "default"
            cur_layer = key
            cur_h3 = cur_h4 = None
            layers[key] = {"name": name, "key": key, "sections": []}
            order.append(key)
            in_layers_table = False
            i += 1
            continue

        # Non-layer ## headers (Layers, Modes, Design, …) end layer context.
        if line.startswith("## "):
            cur_layer = None
            cur_h3 = cur_h4 = None
            in_layers_table = line.strip() == "## Layers"
            i += 1
            continue

        sm = SUBHEADER_RE.match(line)
        if sm:
            level, title = len(sm.group(1)), sm.group(2)
            if level == 3:
                cur_h3, cur_h4 = title, None
            else:
                cur_h4 = title
            i += 1
            continue

        # Table: header row, then separator, then data rows.
        if line.strip().startswith("|") and i + 1 < n and is_separator(lines[i + 1]):
            header = split_row(line)
            i += 2
            rows = []
            while i < n and lines[i].strip().startswith("|"):
                cells = split_row(lines[i].rstrip("\n"))
                rows.append(cells)
                i += 1

            if in_layers_table:
                for cells in rows:
                    if len(cells) < 2:
                        continue
                    km = LAYERS_TABLE_KEY_RE.search(cells[0])
                    k = (km.group(1).upper() if km and km.group(1) else "default")
                    index.append({
                        "key": k,
                        "name": cells[1],
                        "domain": cells[2] if len(cells) > 2 else "",
                    })
                continue

            if cur_layer is None:
                continue

            section_rows = []
            for cells in rows:
                if not cells:
                    continue
                keys = cells[0]
                cols = [c for c in cells[1:]]
                if row_is_empty(cols):
                    continue
                section_rows.append({"keys": keys, "cols": cols})

            if section_rows:
                section_rows.sort(key=lambda r: phys_rank(r["keys"]))
                layers[cur_layer]["sections"].append({
                    "group": cur_h3 if cur_h4 else None,
                    "title": cur_h4 or cur_h3 or layers[cur_layer]["name"],
                    "header": header,
                    "rows": section_rows,
                })
            continue

        i += 1

    # Index legend sorted by the layer key's physical position (default first).
    index.sort(key=lambda e: (0, -1) if e["key"] == "default"
               else (1, phys_rank(e["key"])))

    return {"index": index, "order": order, "layers": layers}


def build_json():
    return json.dumps(parse(), indent=2, ensure_ascii=False) + "\n"


def main():
    ap = argparse.ArgumentParser(description="Generate help_data.json from README.md")
    ap.add_argument("--check", action="store_true",
                    help="Exit 1 if help_data.json is stale")
    args = ap.parse_args()

    data = build_json()

    if args.check:
        existing = ""
        if os.path.exists(OUTPUT):
            with open(OUTPUT) as f:
                existing = f.read()
        if existing != data:
            print("STALE: help_data.json differs from README.md; run build_help.py",
                  file=sys.stderr)
            sys.exit(1)
        return

    with open(OUTPUT, "w") as f:
        f.write(data)


if __name__ == "__main__":
    main()
