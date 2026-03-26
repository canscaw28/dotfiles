#!/bin/bash

# Interactive setup for espanso personal.yml (PII - gitignored)
# Run this on a new machine to populate your personal triggers.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERSONAL_FILE="$SCRIPT_DIR/match/personal.yml"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

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
echo "Espanso Personal Triggers Setup"
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
log_info "Done! Run './reload.sh --espanso' to apply."
