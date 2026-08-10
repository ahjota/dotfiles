<!-- .github/prompts/fix-issue.md -->
<!--
  Reusable prompt template for the droid-issue-fixer GitHub Action.

  The workflow appends live JSON (open issues + in-flight droid attempts)
  after the `---` separator below before passing this file to `droid exec`.
-->

# Task: Fix one open issue from this repository

You are running headlessly inside a GitHub Actions workflow. Your job is to
pick **one** open issue, implement a fix, and commit it on a branch. A
scripted step will push the branch and open a PR for you — **do not push or
open a PR yourself.**

## Before you start

1. Read `AGENTS.md` in the repo root. It contains project conventions you
   must follow (Conventional Commits, in-line comments/docstrings, chezmoi
   `dot_`/`.tmpl` file naming).
2. Understand that this is a **chezmoi** dotfiles repo. Source files use
   `dot_` prefixes (e.g. `dot_zshrc.tmpl` → `~/.zshrc`) and `.tmpl` for
   Go templates. Validate any template changes with:

   ```sh
   chezmoi execute-template --config "$CHEZMOI_CI_CONFIG" < file.tmpl
   ```

## Pick an issue

Below (after the `---` separator) you will find a JSON array of **actionable
issues** — open issues that do not already have an in-flight droid attempt.

Choose the **single most tractable** issue, using these criteria:

- **Clear acceptance criteria** — the issue body describes what "done" looks
  like.
- **Testable on Ubuntu** — the fix can be validated with `bash -n`, `zsh -n`,
  `shellcheck`, or `chezmoi execute-template` (all available on this runner).
- **No secrets, hardware, or platform-specific dependencies** — avoid issues
  that require macOS-only tools, Windows, physical devices, or credentials.
- **Small scope** — prefer a targeted fix over a large refactor.

If **no issue is tractable** under these constraints, stop. Make no changes,
create no branch, and exit. That is an acceptable outcome.

## Implement the fix

1. Create a branch named `droid/issue-<N>-<short-slug>` where `<N>` is the
   issue number and `<short-slug>` is a 2-4 word kebab-case description.
2. Make the **minimal** change that satisfies the issue's acceptance
   criteria. Do not refactor unrelated code.
3. Add or update **in-line comments and docstrings** for any code you write
   or edit, per the repo's AGENTS.md.
4. Validate your changes:
   - `bash -n` on any shell scripts you touched.
   - `zsh -n` on any zsh files you touched (zsh is available).
   - `shellcheck` on any shell scripts you touched (if applicable).
   - `chezmoi execute-template --config "$CHEZMOI_CI_CONFIG" < file.tmpl`
     on any chezmoi template you touched.
5. Commit with a **Conventional Commit** message:
   - Subject: `<type>(<scope>): <subject>` (imperative mood, ≤50 chars).
   - Body: explain *what* and *why*, wrapped at 72 chars.
   - Footer: `Closes #<N>` or `Fixes #<N>`.

## Constraints

- **Never push** to the remote or open a PR — scripted steps handle that.
- **Never mention** pushing, opening PRs, or workflow mechanics in your
  result summary. Your result text is pasted verbatim into the PR body that
  the workflow opens for you — writing "left unpushed" or "no PR opened" in
  that context is confusing and wrong. Describe *what you changed and why*,
  not *what the workflow will do next*.
- **Never modify** `.github/workflows/droid-issue-fixer.yml` or this prompt
  file.
- **Never create** or rotate secrets, API keys, or tokens.
- If the issue requires installing dependencies, prefer what is already on
  the runner (`ubuntu-latest` ships `git`, `gh`, `zsh`, `bash`, `shellcheck`).
- Keep the changeset small and reviewable.

---
