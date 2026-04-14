# Shell functions and environment that don't belong to selection, history
# navigation, or key bindings.

export PATH="$HOME/.local/bin:$PATH"

# Run claude with API key from 1Password instead of subscription.
# Uses an isolated CLAUDE_CONFIG_DIR (~/.claude-api) so API-billed auth
# doesn't clobber the subscription keychain entry. Every entry in ~/.claude
# is symlinked into ~/.claude-api except .credentials.json, so CLAUDE.md,
# memory, agents, settings, hooks, and session history are fully shared.
claude-api() {
  local src="$HOME/.claude"
  local dst="$HOME/.claude-api"
  mkdir -p "$dst"
  for f in "$src"/*(N) "$src"/.*(N); do
    local name=${f:t}
    [[ "$name" == "." || "$name" == ".." ]] && continue
    [[ "$name" == ".credentials.json" ]] && continue
    [[ -L "$dst/$name" || -e "$dst/$name" ]] && continue
    ln -s "$f" "$dst/$name"
  done
  ANTHROPIC_API_KEY=$(op read "op://Personal/Anthropic API Key/credential" --no-newline) \
  CLAUDE_CONFIG_DIR="$dst" \
    command claude "$@"
}
