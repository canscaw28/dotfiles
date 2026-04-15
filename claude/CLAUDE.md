# Global Claude Code Instructions

Personal preferences that apply to every project. Project-specific rules live in each repo's `CLAUDE.md` and override anything here when they conflict.

## Communication

- Be terse. State results and decisions directly; don't narrate deliberation.
- No emojis unless I ask.
- No trailing "summary of what I just did" — I can read the diff.
- Push back when I'm wrong. Don't agree reflexively.
- For exploratory questions, give a recommendation + the main tradeoff in 2-3 sentences. Don't implement until I confirm.

## Commits & VCS

- Do NOT include `Co-Authored-By` lines referencing Claude or Anthropic.
- Do NOT mention Claude, AI, or Anthropic anywhere in commits, PR descriptions, or code comments.
- Make small, atomic commits — one logical change per commit.
- Avoid bulk commits that bundle unrelated changes.
- A commit should be understandable at a glance by any engineer.
- Split multi-feature work into separate commits.
- Commit message focus: the *why*, not the *what*.

## Safety rails

Always confirm before:

- Force-pushing (`git push --force`, `--force-with-lease`).
- Destructive git ops: `reset --hard`, `clean -f`, `branch -D`, `checkout .`, `restore .`.
- `rm -rf` or any recursive delete outside a sandboxed temp dir.
- Editing global config: `~/.gitconfig`, shell rc files, system files.
- Touching `.env`, credential files, or anything that looks like a secret.
- Skipping hooks (`--no-verify`, `--no-gpg-sign`).
- Pushing to `main`/`master` directly.
- Sending anything to external services (Slack, GitHub comments, email, pastebins).

Never use destructive ops as a shortcut to make an obstacle go away. Diagnose root causes instead.

## Code hygiene

- No speculative abstractions. Three repeated lines beats a premature helper.
- No comments explaining *what* code does — names should do that. Only comment when the *why* is non-obvious (hidden constraint, subtle invariant, workaround for a specific bug).
- No backwards-compat shims, feature flags, or "removed" comments when you can just change the code.
- No error handling for impossible cases. Validate only at system boundaries (user input, external APIs).
- Don't create files unless necessary. Prefer editing existing files.
- Never proactively create `*.md` documentation. Only if I ask.
- Delete unused code completely — don't rename to `_var` or leave dead branches.

## Default workflow

For non-trivial work: **explore → plan → code → verify → commit.**

- Explore: read the relevant files before proposing changes.
- Plan: for anything that touches more than a few files, share the plan first.
- Verify: actually run the code / tests / UI before claiming done. If you can't verify (e.g. no browser available), say so explicitly rather than claiming success.
- Commit: only when I ask.

## Tool preferences

- Search content: `rg` (ripgrep), never `grep`.
- Search files: `fd` over `find`; or `Glob`.
- Read files: `Read` / `bat`, never `cat`/`head`/`tail` when a dedicated tool exists.
- Edit files: `Edit` / `Write`, never `sed`/`awk` heredocs.
- GitHub: `gh` CLI for everything (issues, PRs, releases, API).
- macOS: Apple Silicon paths (`/opt/homebrew/...`) — but check; some binaries live in `/usr/local/bin/` (e.g. `hs`).
- Shell: zsh.

## Environment

- macOS, Apple Silicon.
- Shell: zsh (with Powerlevel10k).
- Window manager: AeroSpace (custom build with focus-guard + freeze-tiling patches).
- Hotkey daemon: Karabiner Elements + Hammerspoon.
- Terminal: iTerm2.
- Dotfiles repo: `~/dev/dotfiles` — most `~/.*` configs are symlinks back to it.

## What NOT to do

- Don't restate things auto-memory already knows. Read `MEMORY.md` first.
- Don't run `/init` against arbitrary directories without asking.
- Don't paste large code snippets into responses when a `file:line` reference will do.
- Don't ask permission for trivial reversible actions (reading files, running tests, editing local code). Just do them.
