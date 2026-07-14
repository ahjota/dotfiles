# Personal AGENTS.md

Global guidance for working with coding agents (Droid, Claude Code, OpenCode).

## Development

When you write or edit code, ALWAYS produce a git commit that explains the changeset.

Use the [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/#specification) for commit messages.

## Documentation

Always provide in-line comments and docstrings for any code you write or edit.

## Code Review

- Before reviewing a PR, verify you are on the correct branch and have pulled the latest changes.
- Use worktrees if possible.
- Validate criticisms against existing codebase conventions (e.g., check sibling modules or review developer docs) before flagging them as issues.
- When reviewing, do not make claims about anti-patterns without grounding them in actual repo patterns.

When reviewing a PR, checkout the associated branch into the current repo. Use worktrees if possible.

## Testing

- When library/dependency output differs from existing tests, update the tests to match the new correct output rather than normalizing the library output.

- When fixing log/telemetry rules, request a sample of the actual log/event structure before writing attribute references.

## Tool-Specific Guidance

### Handling Redacted Output in Read Tool

**Problem**: The Read tool redacts sensitive patterns (tokens, fingerprints, credentials) in terminal output to prevent exposure in logs. This can make it hard to copy the correct function names when editing.

**Solution**: When you need to reference sensitive code patterns:

1. **Use `grep` or `sed` to verify actual content** (not affected by Read redaction):

   ```bash
   grep -n "function-name" /path/to/file.go
   sed -n 'START,ENDp' /path/to/file.go | cat -v  # shows actual bytes
   ```

2. **Never copy redacted patterns directly** from Read output — always verify with shell first

3. **The Edit tool is safe to use** — it operates on actual file bytes, not displayed content

**Example**: When you see `TokenFingerprint: *****("test-token")` in Read output, use `grep` to find the real function name before editing.

This applies to all tools that use the Read capability (Claude Code, Droid CLI, etc.).

## Output Formats

- BUGBOT.md and `.cursor/` rule files should be formatted as Cursor bugbot reference guides (machine-readable rule files), NOT human-readable checklists.

## MCP Guidance

### Atlassian MCP (JIRA / Confluence)

When using Atlassian MCP tools (JIRA, Confluence), always default to **standard Markdown syntax** and pass `contentFormat: "markdown"` (the default) if it is a valid parameter, unless otherwise specified.
