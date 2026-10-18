#!/bin/zsh
# Paste keys or clipboard reads in Chrome leak whatever is on the clipboard
# (passwords, card numbers) into pages. Make each one need explicit approval.
jq -c '
  .tool_input as $in
  | ([$in | .. | objects | select(.action == "key") | .text // empty]
     | any(test("(^|[ +])(cmd|command|ctrl|control|meta|super)\\+v($| )"; "i"))) as $paste
  | ([$in | .. | objects | .text? // empty | strings]
     | any(test("clipboard\\.read|execCommand\\(.paste"; "i"))) as $read
  | if $paste or $read then
      {hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: "Uses the clipboard in Chrome. Allow only if you asked for a paste."
      }}
    else empty end
'
