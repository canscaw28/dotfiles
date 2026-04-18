#!/bin/bash

# Sync personal.yml triggers to macOS text replacements
# (System Settings > Keyboard > Text Replacements)
#
# Writes to ~/Library/KeyboardServices/TextReplacements.db, which is
# the CloudKit-synced store. Entries appear in System Settings and
# sync to iOS via iCloud.
#
# Preserves any existing macOS replacements not managed by this script.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERSONAL_FILE="$SCRIPT_DIR/personal.yml"

if [[ ! -f "$PERSONAL_FILE" ]]; then
    echo "[SKIP] $PERSONAL_FILE not found — run setup-personal.sh first"
    exit 0
fi

/usr/bin/python3 - "$PERSONAL_FILE" <<'PYEOF'
import sys, re, sqlite3, uuid, time, os

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

db_path = os.path.expanduser("~/Library/KeyboardServices/TextReplacements.db")
conn = sqlite3.connect(db_path)
c = conn.cursor()

# CoreData timestamp: seconds since 2001-01-01
now = time.time() - 978307200

# Get current max Z_PK
c.execute("SELECT MAX(Z_PK) FROM ZTEXTREPLACEMENTENTRY")
max_pk = c.fetchone()[0] or 0

added = 0
updated = 0

for shortcut, phrase in triggers.items():
    c.execute(
        "SELECT Z_PK, ZPHRASE FROM ZTEXTREPLACEMENTENTRY WHERE ZSHORTCUT = ? AND ZWASDELETED = 0",
        (shortcut,)
    )
    row = c.fetchone()

    if row:
        pk, existing_phrase = row
        if existing_phrase != phrase:
            c.execute(
                "UPDATE ZTEXTREPLACEMENTENTRY SET ZPHRASE = ?, ZTIMESTAMP = ?, ZNEEDSSAVETOCLOUD = 1 WHERE Z_PK = ?",
                (phrase, now, pk)
            )
            updated += 1
    else:
        max_pk += 1
        unique_name = str(uuid.uuid4()).upper()
        c.execute(
            "INSERT INTO ZTEXTREPLACEMENTENTRY (Z_PK, Z_ENT, Z_OPT, ZNEEDSSAVETOCLOUD, ZWASDELETED, ZTIMESTAMP, ZPHRASE, ZSHORTCUT, ZUNIQUENAME) VALUES (?, 1, 1, 1, 0, ?, ?, ?, ?)",
            (max_pk, now, phrase, shortcut, unique_name)
        )
        added += 1

# Update Z_PRIMARYKEY max counter
c.execute(
    "UPDATE Z_PRIMARYKEY SET Z_MAX = ? WHERE Z_NAME = 'TextReplacementEntry'",
    (max_pk,)
)

conn.commit()
conn.close()

parts = []
if added:
    parts.append(f"{added} added")
if updated:
    parts.append(f"{updated} updated")
if not parts:
    parts.append("all up to date")
print(f"[INFO] macOS text replacements: {', '.join(parts)} ({len(triggers)} total triggers)")
PYEOF
