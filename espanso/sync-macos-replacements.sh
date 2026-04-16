#!/bin/bash

# Sync espanso personal.yml triggers to macOS text replacements
# (System Settings > Keyboard > Text Replacements)
#
# Preserves any existing macOS replacements not managed by espanso.
# Syncs to iCloud automatically, so replacements appear on iOS too.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERSONAL_FILE="$SCRIPT_DIR/match/personal.yml"

if [[ ! -f "$PERSONAL_FILE" ]]; then
    echo "[SKIP] $PERSONAL_FILE not found — run setup-personal.sh first"
    exit 0
fi

/usr/bin/python3 - "$PERSONAL_FILE" <<'PYEOF'
import sys, re, subprocess, plistlib

personal_file = sys.argv[1]

# Parse trigger/replace pairs from personal.yml
triggers = {}
with open(personal_file) as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    m = re.match(r'\s*-\s*trigger:\s*"(.+)"', line)
    if m and i + 1 < len(lines):
        r = re.match(r'\s*replace:\s*"(.+)"', lines[i + 1])
        if r:
            triggers[m.group(1)] = r.group(1)

if not triggers:
    print("[SKIP] No triggers found in personal.yml")
    sys.exit(0)

# Read existing macOS text replacements
try:
    out = subprocess.check_output(
        ["defaults", "read", "-g", "NSUserDictionaryReplacementItems"],
        stderr=subprocess.DEVNULL
    )
    raw = out.decode()
    existing = []
    for m in re.finditer(r'replace\s*=\s*"?([^";]+)"?\s*;\s*with\s*=\s*"?([^";]+)"?', raw):
        existing.append((m.group(1).strip(), m.group(2).strip()))
except subprocess.CalledProcessError:
    existing = []

# Merge: keep non-espanso entries, replace/add espanso ones
espanso_shortcuts = set(triggers.keys())
merged = [(k, v) for k, v in existing if k not in espanso_shortcuts]
merged.extend(triggers.items())

# Build plist array and write
plist_dicts = [{"on": 1, "replace": k, "with": v} for k, v in merged]
plist_data = plistlib.dumps(plist_dicts, fmt=plistlib.FMT_XML).decode()

# defaults write expects the value as a plist fragment
subprocess.check_call([
    "defaults", "write", "-g", "NSUserDictionaryReplacementItems",
    "-array"
] + [
    f'{{"on" = 1; "replace" = "{k}"; "with" = "{v}";}}'
    for k, v in merged
])

print(f"[INFO] Synced {len(triggers)} espanso triggers to macOS text replacements")
if len(merged) > len(triggers):
    print(f"[INFO] Preserved {len(merged) - len(triggers)} non-espanso replacements")
PYEOF
