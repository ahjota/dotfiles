<!-- .github/prompts/consistency-sweep.md -->
<!--
  Reusable prompt template for the droid-consistency-sweep GitHub Action
  ("Sweeper Minion").

  The workflow appends the sweep-results JSON (per-file failures from
  scripts/consistency-sweep.sh) after the `---` separator below before
  passing this file to `droid exec`.
-->

# Task: Draft GitHub issues for dotfile consistency failures

You are running headlessly inside a GitHub Actions workflow. A scripted
validation suite has already run `shellcheck`, `chezmoi execute-template`,
`bash -n`, and `zsh -n` across this chezmoi dotfiles repo. Its results are
appended below the `---` separator as JSON.

Your job is to **author GitHub issue content** (titles + bodies) for the
failures and write them to disk. A scripted step will create the issues with
`gh issue create` — **do not run `gh`, do not push, do not edit any repo
files.** You only write files under `.droid-temp/issues/`.

## Output contract

Write exactly **one Markdown file per issue** plus a **manifest** that the
scripted step reads. All output goes under `.droid-temp/issues/`.

### Manifest: `.droid-temp/issues/manifest.json`

A JSON array. Each entry:

```json
{
  "slug": "dot-bashrc-tmpl",
  "title": "[sweeper] dot_bashrc.tmpl — shellcheck warnings",
  "file": "dot_bashrc.tmpl",
  "body_file": "dot-bashrc-tmpl.md"
}
```

- `slug` — short, stable, filesystem-safe identifier (lowercase, hyphenated).
  Used for dedup, so keep it deterministic across runs for the same file.
- `title` — starts with `[sweeper]` and names the file + a one-phrase summary.
- `file` — the repo-relative path of the failing file (from the JSON `file`
  field). Use `"__summary__"` for a single summary issue.
- `body_file` — filename of the Markdown body inside `.droid-temp/issues/`.

### Body files: `.droid-temp/issues/<slug>.md`

GitHub-flavored Markdown. For a per-file issue include:

- The failing file path and a short description of what the check does.
- A fenced block quoting the relevant check output (trim very long output to
  the most actionable ~40 lines; note when truncated).
- A "Suggested fix" section with concrete, specific guidance grounded in the
  actual output — do not invent problems that are not in the JSON.

For a summary issue, list every failing file with its checks and link-worthy
paths, followed by an aggregate "Next steps" section.

## Grouping rule

The workflow decides grouping, but apply it here when shaping the manifest:

- **1–3 failing files** → one issue per file (`file` = the file path).
- **4 or more failing files** → a single summary issue (`file` = `"__summary__"`)
  covering all of them.

If you judge that one failure is clearly trivial and worth folding into
another, you may — but never drop a failing file entirely. Every `file` in the
input JSON must be represented somewhere in the manifest.

## Before you start

1. Read `AGENTS.md` in the repo root for project conventions.
2. You may read the failing files in the repo to ground your suggested fixes,
   but **do not modify them**.

## Quality bar

- Ground every claim in the appended JSON output. Do not report issues that
  are not present in the data.
- Keep titles under 72 characters.
- Prefer specific, copy-pasteable fix advice over generic platitudes.
