# Worked example — CFX-5928 epic

A complete run from the original session that this skill formalizes. Useful as a calibration reference for what "good" curation looks like.

## Project context

- Codebase: DataRobot CLI (`dr`), a Go-based cobra CLI
- Repo: `/Users/aj.alon/workspace/cli`
- JIRA project: `CFX` (Code First Experience)
- Component: `DR CLI`
- Conventions documented in repo `CLAUDE.md`: viperx wrapper for config, `%w` error wrapping, singular cobra command names, `tui.Run()` for TUI models

## Phase 1 — what the parallel scan found

Three `Explore` agents in parallel returned:

- **TODO inventory** — 33 TODO/FIXME comments across 19 files. No FIXME/HACK/XXX/BUG. Three already referenced JIRA tickets (CFX-5206 ×2, CFX-3996 ×1).
- **Refactor smells** — 13 distinct opportunities: 1 depguard violation (direct viper import), 1 boilerplate-DRY hotspot in `cmd/root.go`, 1 duplicated registry fetch, 1 magic-number-extraction, ~15 inconsistent error-wrapping sites, ~10–15 capitalization inconsistencies, 5 packages with zero tests.
- **Codebase survey** — top-level `cmd/`, `internal/`, `tui/` layout; major internal packages and their purposes; cobra command tree.

## Phase 2 — user's curation choices

| Question | Answer |
|---|---|
| Tracked tickets (CFX-5206, CFX-3996) | Include as "see existing" notes (out-of-scope section) |
| Scope | Tight: 10–15 best junior tasks |
| Effort scale | Hours estimate |

## Phase 3 — the curated 14

After filtering 33 TODOs + 13 refactor smells down to the best junior-friendly subset:

| # | Title | Effort | SP |
|---|---|---|---|
| 1 | Replace direct `viper` import in envbuilder | 1–2h | 0.5 |
| 2 | Collapse repeated `viperx.BindPFlag` boilerplate in `cmd/root.go` | 1–2h | 0.5 |
| 3 | Extract duplicated plugin-registry fetch into a shared helper | 1–2h | 0.5 |
| 4 | Extract magic 30s HTTP timeout to a shared constant | 1–2h | 0.5 |
| 5 | Standardize error wrapping across `internal/plugin` | 4–6h | 1.5 |
| 6 | Normalize error-message capitalization | 2–3h | 1 |
| 7 | Add unit tests for `internal/drapi` | 6–8h | 2 |
| 8 | Add unit tests for `internal/log` | 2–3h | 1 |
| 9 | Add unit tests for `internal/shell` | 1–2h | 0.5 |
| 10 | Add unit tests for `internal/task` | 6–8h | 2 |
| 11 | Move dotenv state directory path through `viperx` | 1–2h | 0.5 |
| 12 | Wrap errors and validate manifest name in plugin discovery | 2–3h | 1 |
| 13 | Pre-check `uv` installation before component update | 1–2h | 0.5 |
| 14 | Refactor template-name extraction in telemetry | 4–6h | 1.5 |

Total: 13.5 SP across 14 tickets.

## Phase 3 — explicit exclusions

Surfaced separately so the user knows they were considered and consciously skipped:

- **Already tracked**: CFX-5206 (telemetry SessionID/UserID), CFX-3996 (component info display).
- **Too risky / large for juniors**:
  - List filtering bugs in `cmd/component/shared/updateModel.go:230` — needs senior call on fix vs remove.
  - `validateEnvironment` re-implementation in `cmd/start/model.go` — architecture-level work.
  - Component-configure re-enablement at `cmd/templates/setup/cmd.go:52` — blocked on test suite.
  - File-based plugin registry caching with TTL — design call.
  - Parallel manifest fetching with errgroup — concurrency change, easy to get wrong.

## Phase 4 — ticket creation

Created 1 epic + 14 child Tasks in parallel:

- Epic: **CFX-5928** "Tech-debt cleanup: junior engineer onboarding tasks (dr CLI)"
- Children: **CFX-5929 through CFX-5942**

Each child Task carried:
- `parent: "CFX-5928"`
- `components: [{"name": "DR CLI"}]`
- `customfield_10004` = Story Points (per the table above)
- `customfield_19108` = `[{"value": "regular _maintenance"}]` (the typo'd option value, see `jira-fields.md`)

Spot-checked CFX-5929 with `getJiraIssue` to confirm all fields took.

## Calibration notes

- **Curation matters more than the scan.** The scan returned 46 candidates (33 TODOs + 13 smells); the right output was 14 tickets.
- **Suggested sequencing helps onboarding.** Order the table so a junior builds skill: tests → DRY → conventions → bigger refactors. This was added below the table in the epic description.
- **Story Points float values are fine.** The CFX setup uses 0.5 and 1.5 without complaint.
- **One spot-check is worth doing.** Custom-field IDs can silently fail; reading back one issue's fields catches that immediately.
