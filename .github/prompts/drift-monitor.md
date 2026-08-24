<!-- .github/prompts/drift-monitor.md -->
<!--
  Reusable prompt template for the droid-drift-monitor GitHub Action
  (Meter Reader Minion).

  The workflow appends a run-context block (date, runner) after the `---`
  separator below before passing this file to `droid exec`.
-->

# Task: Scan for outdated version/model pins and bump them

You are running headlessly inside a GitHub Actions workflow. Your job is to
enumerate every pinned version or model reference in this repo, check each
against the latest available, and bump the stale ones on a branch. A
scripted step will push the branch and open a PR for you — **do not push or
open a PR yourself.**

## Before you start

1. Read `AGENTS.md` in the repo root. It contains project conventions you
   must follow (Conventional Commits, in-line comments/docstrings, chezmoi
   `dot_`/`.tmpl` file naming).
2. Understand that this is a **chezmoi** dotfiles repo. Source files use
   `dot_` prefixes (e.g. `dot_zshrc.tmpl` → `~/.zshrc`) and `.tmpl` for
   Go templates.

## Enumerate pins

Scan the repo for these categories of versioned references:

1. **Factory model pins** — `model:` frontmatter fields in
   `private_dot_factory/private_droids/*.md` and `--model` arguments in
   `.github/workflows/*.yml`.
2. **Antidote plugin repos** — lines in `dot_zsh_plugins.txt` that follow
   the `user/repo` format (ignoring comment lines starting with `#`).
3. **Any other pinned versions** you discover (e.g. hardcoded version
   numbers in scripts, templates, or config files).
4. **Brew references (future-proofing)** — no Brewfile or brew-bundle
   manifest exists in this repo today. If one has appeared since this
   prompt was written, enumerate its pinned formulae/casks/taps.
   Additionally, flag any renamed or deprecated formula/cask names in
   README install instructions (e.g. `font-fira-code-nerd-font`).

## Check each pin against the latest

- **Factory model pins**: Fetch `https://docs.factory.ai/models.md` and
  check whether any pinned model ID appears next to a `‡ Deprecated`
  marker. Also check `https://docs.factory.ai/changelog/release-notes.md`
  for "Deprecations" or "retirement" entries mentioning the pinned models.
  Note that explicit `--model` pins bypass the CLI's default-model
  validation, so a deprecated pin will not be caught at run time — this
  scan is the safety net.
- **Antidote plugin repos**: Check GitHub for each repo. If a repo was
  renamed, archived, or deleted, flag it for a replacement. For available
  repos, report the latest release tag in your result summary but **do
  not edit `dot_zsh_plugins.txt`** — antidote pins plugins locally via
  `antidote update`, and no lockfile is committed to this repo. The PR
  body should list new releases as an informational report.
- **Other pinned versions**: Check the appropriate source (registry,
  release page, etc.) and bump if a newer stable version exists.
- **Brew references**: If a Brewfile exists, check for deprecated/renamed
  formulae via `brew info` or the Homebrew API. For README install
  instructions, verify the formula/cask name still resolves.

## Implement the bumps

1. Create a branch named `droid/drift-<YYYY-MM-DD>` using the date from
   the run context below the `---` separator.
2. Make the **minimal** change for each stale pin — update the version or
   model string in place. Do not refactor unrelated code or reflow
   surrounding content.
3. Add or update **in-line comments and docstrings** for any code you
   write or edit, per the repo's AGENTS.md.
4. For **model pins inside existing workflow files** (`.github/workflows/
   *.yml`): you may edit the `--model` argument value, but **do not alter
   any other workflow logic** (steps, job structure, triggers, permissions,
   etc.).
5. For **antidote plugins**: do not edit `dot_zsh_plugins.txt` unless a
   repo was renamed/archived and needs a replacement URL. New releases are
   reported in the result summary only.
6. Commit with a **Conventional Commit** message:
   - Subject: `chore(deps): <subject>` (imperative mood, ≤50 chars).
   - Body: list each bump (old → new) and any report-only findings, wrapped
     at 72 chars.
   - Footer: `Refs #135`.

## Constraints

- **Never push** to the remote or open a PR — scripted steps handle that.
- **Never mention** pushing, opening PRs, or workflow mechanics in your
  result summary. Your result text is pasted verbatim into the PR body that
  the workflow opens for you — writing "left unpushed" or "no PR opened" in
  that context is confusing and wrong. Describe _what you checked, what you
  bumped, and what you found_, not _what the workflow will do next_.
- **Never modify** `.github/workflows/droid-drift-monitor.yml` or this
  prompt file. You may edit `--model` arguments in _other_ workflow files,
  but nothing else in them.
- **Never create** or rotate secrets, API keys, or tokens.
- If **no pins are outdated**, stop. Make no changes, create no branch, and
  exit. That is an acceptable outcome — your result summary should state
  that all pins are current.

---
