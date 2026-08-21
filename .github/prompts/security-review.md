# Task: Run a full-codebase security review

You are running headlessly inside a GitHub Actions workflow. Your job is to
perform a **read-only** security review of this chezmoi dotfiles repository
using the built-in `security-review` skill, then produce a structured
findings report that the workflow will publish as a GitHub issue.

## Scope

Review every tracked source file in the repository, with special attention
to:

- Shell injection vectors in bash/zsh templates and scripts
- Unquoted variable expansions in shell rc files
- Credential handling (secrets, tokens, API keys) in shell configuration
- Unsafe `curl | sh` or `curl | bash` patterns
- Chezmoi template `{{ ... }}` eval risks, especially around user-controlled
  data or secrets

## Methodology

Use the built-in `security-review` skill. Apply STRIDE, OWASP Top 10:2021,
OWASP Top 10 for LLM Applications:2025, and supply-chain analysis where
relevant. Only report findings that have a realistic exploit path or
represent a concrete security risk. Avoid low-value style nits.

## Output format

Write your findings as Markdown with the following structure:

```markdown
## Summary

One-paragraph overview of the review: number of findings, highest severity,
and broad themes.

## Findings

### 1. <Concise title>

- **Severity:** Critical / High / Medium / Low
- **File:** `path/to/file`
- **Description:** What the issue is and why it matters.
- **Recommendation:** Concrete fix or mitigation.

### 2. ...

## No findings

If no high-confidence security issues are found, write a single sentence
under this heading explaining that the scan found no actionable findings.
```

## Constraints

- Do **not** modify any files.
- Do **not** push branches or open pull requests.
- Do **not** create, rotate, or expose secrets or API keys.
- Keep the report factual and actionable; cite file paths and line numbers
  where possible.
