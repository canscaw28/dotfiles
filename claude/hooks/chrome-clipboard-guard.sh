#!/bin/zsh
# Paste keys or clipboard reads in Chrome leak whatever is on the clipboard
# (passwords, card numbers) into pages. Claude Code asks first; Codex can't
# ask from a hook, so it passes "deny" and the user pastes by hand instead.
decision=${1:-ask}
jq -c --arg decision "$decision" '
  .tool_input as $in
  | ([$in | .. | objects | (select(.action == "key") | .text), .key | strings]
     | any(test("(^|[ +])(cmd|command|ctrl|control|meta|super)\\+([a-z]+\\+)*v($| )"; "i"))) as $paste
  | ([$in | .. | strings]
     | any(test("clipboard\\.read|execCommand\\(.paste"; "i"))) as $read
  | if $paste or $read then
      {hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: $decision,
        permissionDecisionReason: (if $decision == "deny"
          then "Clipboard use in Chrome is blocked. If the user asked for a paste, ask them to paste it themselves."
          else "Uses the clipboard in Chrome. Allow only if you asked for a paste." end)
      }}
    else empty end
'
