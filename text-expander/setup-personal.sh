#!/bin/bash

# Setup for personal.yml (PII - gitignored). Run this on a new machine to
# populate your personal triggers.
#
# Usage:
#   setup-personal.sh           # interactive prompts
#   setup-personal.sh --import  # import existing entries from macOS text
#                               # replacements (e.g. synced via iCloud from
#                               # another device). Exits non-zero if the DB
#                               # is missing or empty so callers can fall back
#                               # to the interactive flow.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERSONAL_FILE="$SCRIPT_DIR/personal.yml"
BASE_FILE="$SCRIPT_DIR/base.yml"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

import_from_macos() {
    local db="$HOME/Library/KeyboardServices/TextReplacements.db"
    if [[ ! -f "$db" ]]; then
        log_skip "macOS text replacements DB not found at $db"
        return 1
    fi

    /usr/bin/python3 - "$db" "$PERSONAL_FILE" "$BASE_FILE" <<'PYEOF'
import sys, os, sqlite3, re

db_path, personal_file, base_file = sys.argv[1], sys.argv[2], sys.argv[3]

# Load triggers already in base.yml so we don't shadow them in personal.yml
base_triggers = set()
if os.path.exists(base_file):
    with open(base_file) as f:
        for line in f:
            m = re.match(r'\s*-\s*trigger:\s*"(.+)"', line)
            if m:
                base_triggers.add(m.group(1))

# Triggers already in personal.yml (so re-running --import is idempotent)
existing_triggers = set()
if os.path.exists(personal_file):
    with open(personal_file) as f:
        for line in f:
            m = re.match(r'\s*-\s*trigger:\s*"(.+)"', line)
            if m:
                existing_triggers.add(m.group(1))

conn = sqlite3.connect(db_path)
c = conn.cursor()
c.execute("SELECT ZSHORTCUT, ZPHRASE FROM ZTEXTREPLACEMENTENTRY WHERE ZWASDELETED = 0 ORDER BY ZSHORTCUT")
rows = c.fetchall()
conn.close()

if not rows:
    print("[SKIP] No entries in macOS text replacements DB")
    sys.exit(2)

if not os.path.exists(personal_file):
    with open(personal_file, "w") as f:
        f.write("# Personal/PII expansions (gitignored - not committed to repo)\n\nmatches:\n")

def yaml_quote(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'

added = 0
skipped_existing = 0
skipped_base = 0

with open(personal_file, "a") as f:
    for shortcut, phrase in rows:
        if not shortcut or not phrase:
            continue
        if shortcut in base_triggers:
            skipped_base += 1
            continue
        if shortcut in existing_triggers:
            skipped_existing += 1
            continue
        f.write(f"  - trigger: {yaml_quote(shortcut)}\n")
        f.write(f"    replace: {yaml_quote(phrase)}\n")
        added += 1

parts = [f"{added} added"]
if skipped_existing:
    parts.append(f"{skipped_existing} already in personal.yml")
if skipped_base:
    parts.append(f"{skipped_base} shadowed by base.yml")
print(f"[INFO] Imported from macOS: {', '.join(parts)}")
PYEOF
}

if [[ "${1:-}" == "--import" ]]; then
    import_from_macos
    exit $?
fi

# Check if a trigger already exists in the file
trigger_exists() {
    [[ -f "$PERSONAL_FILE" ]] && grep -q "trigger: \"$1\"" "$PERSONAL_FILE"
}

# Prompt for a value and append to personal.yml
prompt_trigger() {
    local trigger="$1"
    local description="$2"
    local comment="$3"

    if trigger_exists "$trigger"; then
        log_skip "$trigger already set"
        return
    fi

    echo -n "$description [$trigger]: "
    read -r value
    if [[ -z "$value" ]]; then
        log_skip "$trigger skipped (empty)"
        return
    fi

    # Add comment header if provided and not already in file
    if [[ -n "$comment" ]] && ! grep -q "# $comment" "$PERSONAL_FILE" 2>/dev/null; then
        echo "" >> "$PERSONAL_FILE"
        echo "  # $comment" >> "$PERSONAL_FILE"
    fi

    cat >> "$PERSONAL_FILE" <<EOF
  - trigger: "$trigger"
    replace: "$value"
EOF

    log_info "$trigger set"
}

# Initialize file if it doesn't exist
if [[ ! -f "$PERSONAL_FILE" ]]; then
    cat > "$PERSONAL_FILE" <<'EOF'
# Personal/PII expansions (gitignored - not committed to repo)

matches:
EOF
    log_info "Created $PERSONAL_FILE"
else
    log_info "Updating existing $PERSONAL_FILE"
fi

echo ""
echo "========================================="
echo "Personal Triggers Setup"
echo "========================================="
echo ""
echo "Press Enter to skip any field."
echo ""

prompt_trigger ";pe"   "Personal email"     "Email"
prompt_trigger ";ce"   "Company email"      ""
prompt_trigger ";ge"   "Girlfriend email"   ""
prompt_trigger ";pp"   "Personal phone"     "Phone"
prompt_trigger ";gp"   "Girlfriend phone"   ""
prompt_trigger ";pa"   "Home address"       "Address"
prompt_trigger ";lg"   "GitHub URL"         "Social / URLs"
prompt_trigger ";ll"   "LinkedIn URL"       ""
prompt_trigger ";li"   "Instagram URL"      ""
prompt_trigger ";lx"   "X/Twitter URL"      ""
prompt_trigger ";zoom" "Zoom meeting link"  "Meeting"

echo ""

# Sync to macOS text replacements (iCloud → iOS)
"$SCRIPT_DIR/sync-macos-replacements.sh"

echo ""
log_info "Done! Run './reload.sh --text-expander' to apply."
