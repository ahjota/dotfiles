# Personal AGENTS.md

Global guidance for working with coding agents (Droid, Claude Code, OpenCode).

## Development

Override default behavior: Always produce a git commit that explains the changeset after any substantive code change, without waiting for explicit request. Use the [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/#specification) for commit messages. Be descriptive in the message.

## Repository hygiene

Write transient files (drafts, audit notes, agent outputs, local
experiment logs) to the repository's `tmp/` directory. `tmp/` is gitignored
so it stays out of commits; never drop throwaway files in the repo root.

## Documentation

Override default behavior: Always provide in-line comments and docstrings for any code you write or edit.

## Code Review

- Before reviewing a PR, verify you are on the correct branch and have pulled the latest changes.
- Checkout the associated branch into the current repo; use worktrees if possible.
- Validate criticisms against existing codebase conventions (e.g., check sibling modules or review developer docs) before flagging them as issues.
- When reviewing, do not make claims about anti-patterns without grounding them in actual repo patterns.

## Testing

- When library/dependency output differs from existing tests, update the tests to match the new correct output rather than normalizing the library output.

- When fixing log/telemetry rules, request a sample of the actual log/event structure before writing attribute references.

## Tool-Specific Guidance

### Handling Redacted Output in Read Tool

**Problem**: The Read tool redacts sensitive patterns (tokens, fingerprints, credentials) in terminal output to prevent exposure in logs. This can make it hard to copy the correct function names when editing.

**Solution**: When you need to reference sensitive code patterns:

1. **Use `ripgrep`, `grep` or `sed` to verify actual content** (not affected by Read redaction):

   ```bash
   grep -n "function-name" /path/to/file.go
   sed -n 'START,ENDp' /path/to/file.go | cat -v  # shows actual bytes
   ```

2. **Never copy redacted patterns directly** from Read output — always verify with shell first

3. **The Edit tool is safe to use** — it operates on actual file bytes, not displayed content

**Example**: When you see `TokenFingerprint: *****("test-token")` in Read output, use `grep` to find the real function name before editing.

This applies to all tools that use the Read capability (Claude Code, Droid CLI, etc.).

### Shell heredocs inside command substitution

Heredocs inside `$(...)` command substitution are fragile in POSIX shell. The closing delimiter and closing `)` can confuse the parser, especially when the heredoc body contains parentheses, backticks, or `$` characters. This affects patterns like `gh pr create --body "$(cat <<'EOF' ... EOF)"`.

**Workaround**: write the content to a temp file first, then pass it by path or flag:

```sh
gh pr create --body-file /tmp/pr-body.md
git commit -F /tmp/commit-msg.txt
```

For git commits specifically, `git commit -F - <<'EOF'` (stdin heredoc without command substitution) works reliably and avoids the issue entirely.

## Output Formats

- BUGBOT.md and `.cursor/` rule files should be formatted as Cursor bugbot reference guides (machine-readable rule files), NOT human-readable checklists.

## MCP Guidance

### Atlassian MCP (JIRA / Confluence)

When using Atlassian MCP tools (JIRA, Confluence), always default to **standard Markdown syntax** and pass `contentFormat: "markdown"` (the default) if it is a valid parameter, unless otherwise specified.

## Technical decision docs (pros/cons, Confluence)

**Style**

- One clause per bullet. Cut hedges.
- Bold lead phrase + one supporting clause for flagged risks, not a paragraph.
- State shared rationale once; cross-reference it elsewhere instead of repeating.

**Sourcing**

- Re-read the actual Slack/doc message before paraphrasing it — don't infer.
- Surface unresolved sub-decisions (e.g. salt strategy) as open questions, don't quietly settle them.

**Confluence**

- Never break a line inside a table cell — breaks row parsing, mangles the table.
- Re-fetch the page immediately before every edit; people edit directly between calls.
- After reordering a numbered list, grep the doc for stale "see Item N" references.

**Process**

- Confirm doc structure/scope before drafting, not after.
- When the recommendation changes, audit every downstream section that assumed the old one.
