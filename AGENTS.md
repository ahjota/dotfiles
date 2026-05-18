# Personal AGENTS.md

Global guidance for working with coding agents (Droid, Claude Code, OpenCode) across all projects.

## Documentation

Always provide in-line comments and docstrings for any code you write or edit.

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
