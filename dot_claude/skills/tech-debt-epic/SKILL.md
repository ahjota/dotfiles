---
name: tech-debt-epic
description: Scan a codebase for tech-debt (TODOs, FIXMEs, refactor smells, missing tests, deprecated patterns), curate a junior-engineer-friendly ticket list, and create a JIRA epic with child Tasks under it via the Atlassian MCP. Use this whenever the user wants to "create a tech-debt epic", "find TODOs and turn them into tickets", "build an onboarding backlog", "spin up cleanup tasks for junior engineers", "audit code smells and file JIRA tickets", or anything that pairs a codebase scan with JIRA ticket creation. Trigger even if the user only mentions one half of the workflow (e.g. "find me low-hanging-fruit refactors" or "create a JIRA epic for cleanup work") — the skill handles both sides and asks before creating tickets.
---

# Tech-Debt Epic

End-to-end workflow: scan a repo → curate a ticket table → review with the user → create the JIRA epic and child Tasks.

This skill exists because the manual version is repetitive and easy to do badly: ad-hoc ripgrep, forgetting to exclude vendored code, missing custom-field IDs, getting Story Points wrong, creating tickets one-at-a-time. The skill enforces parallelism where it helps, asks the right questions up front, and centralizes the JIRA quirks.

## When to invoke

Trigger on phrases like:

- "create a tech-debt epic"
- "find TODOs in this repo and file them as tickets"
- "build an onboarding backlog of cleanup tasks"
- "audit refactor opportunities and create JIRA tickets"
- "I want junior-engineer tickets for the codebase"

Even if the user only asks for half the workflow (just the scan, or just the ticket creation from a list they provide), invoke this skill — it handles partial flows.

## Phase 1 — Scan the codebase (parallel)

Spawn **up to three Explore subagents in parallel in a single message**. Independent searches finish faster and protect the main context from raw grep dumps. Three is a reasonable max — quality of prompts beats quantity of agents.

Suggested split (adjust to the request):

1. **TODO inventory.** `rg -n --type <lang> '(TODO|FIXME|HACK|XXX|BUG)' -C 3` excluding `vendor/`, `.git/`, `testdata/`, `node_modules/`. For each match, capture file:line, comment text, and 3–5 lines of surrounding context. Group findings by theme (auth, TUI, config, tests, etc.). Flag TODOs that already reference a ticket key (e.g. `TODO(PROJ-123)`).
2. **Refactor smells.** Look for: duplicated logic across 3+ sites, deprecated APIs (`ioutil.*`, etc.), magic numbers and repeated string literals, inconsistent error wrapping (`%w` vs `%s` vs bare strings), ignored errors with `_ =`, untested packages (find dirs with no `*_test.*` files), depguard / linter rule violations the user's project enforces, functions over ~150 lines, naming inconsistencies (e.g. plural vs singular conventions). Give concrete file:line examples — never "there's some duplication".
3. **Codebase survey.** Top-level layout, major packages and their purpose, command/route tree, test-coverage patterns, project-specific conventions documented in `CLAUDE.md` / `AGENTS.md` / `CONTRIBUTING.md`. This becomes the bucketing reference for the curated table.

Tell each subagent the goal explicitly: "this is for a JIRA epic of junior-engineer onboarding tasks, so I want concrete, well-scoped findings with file:line evidence." Vague prompts produce vague reports.

## Phase 2 — Ask before curating

Before writing the table, ask the user via `AskUserQuestion`. Don't make these up — the answers shape the deliverable. Bundle them in **one** AskUserQuestion call (multiple questions, max 4):

1. **Scope** — Tight (10–15 best junior tasks), Broad (20–30 items, some stretch), or Exhaustive (everything found).
2. **Effort scale** — T-shirt (S/M/L), Story points (Fibonacci), or Hours (e.g. 1–2h, 4–6h).
3. **Already-tracked TODOs** — Exclude entirely, Include as "see existing" notes, or Include normally.
4. **JIRA target** (only if not already known from context) — project key, default Components, default Work Type, parent-epic preference (create new vs. add under existing).

If the conversation already established defaults (e.g. the user said "project ABC, components identity service"), don't re-ask — confirm them once and proceed.

## Phase 3 — Curate the table

Curate to the requested scope. Selection criteria for junior-friendly tickets:

- **Low blast radius** — change is local to one or two files, no cross-cutting redesign.
- **Teaches a project convention** — the contributor learns a real pattern (error wrapping, config isolation, test conventions) by doing the ticket.
- **Verifiable** — outcome can be checked by running the project's lint and test commands, or a quick manual smoke-test.

Exclude (and surface as "Out of Scope"):

- Already-tracked TODOs (per the user's choice in Phase 2).
- Items that are too large or architectural for a junior (multi-system rewrites, blocked-on-other-work, design decisions still open). List these separately so the user knows they were seen and consciously skipped.

Effort conversion when the user picked **Hours** and the JIRA setup uses Story Points:

- Default ratio: **2 SP per 8h dev day = 1 SP per 4h**.
- Use the high end of the range (a "1–2h" task → 2h → 0.5 SP; "4–6h" → 6h → 1.5 SP).
- Common mappings: 1–2h → 0.5 SP · 2–3h → 1 SP · 4–6h → 1.5 SP · 6–8h → 2 SP. The Story Points field is float-typed, so 0.5 and 1.5 are valid.
- If the user gave a different ratio in Phase 2, recompute.

### Output format (final table)

Produce a markdown table with columns: `# | Title | Description | Possible Solution | Effort`.

Below the table, include:

- A **Verification** block — the lint / test / smoke-test commands the engineer should run for every ticket.
- A **Suggested Sequencing** ordering — group easier tickets first so a junior builds skill before tackling the harder ones.
- An **Out of Scope (Already Tracked)** subsection.
- An **Explicitly Excluded** subsection for the too-big-for-juniors items.

Save the curated table somewhere durable. If the conversation is in plan mode, write it to the plan file. Otherwise, present it inline and ask the user to review before creating tickets.

## Phase 4 — Create JIRA tickets (only after explicit approval)

**Do not create tickets without the user saying "create them" / "go ahead" / equivalent.** The scan and curation are useful on their own; the user may want to edit or copy-paste before any tickets are filed.

When approved:

1. **Resolve cloudId** — call `getAccessibleAtlassianResources`. Pick the right site if multiple are returned.
2. **Confirm issue types** — call `getJiraProjectIssueTypesMetadata` with the project key. Confirm "Epic" and "Task" exist (issue type names vary across JIRA configurations).
3. **Find custom-field IDs** — call `getJiraIssueTypeMetaWithFields` for the Task issue type. Story Points and Work Type are custom fields with project-specific IDs. **Do not hardcode IDs across projects.** See `references/jira-fields.md` for what to look for and a worked example.
4. **Create the epic first.** Use markdown format for the description (`contentFormat: "markdown"`). Put the full curated table in the description so the epic is self-contained.
5. **Create child Tasks in parallel.** Single message, one `createJiraIssue` tool call per ticket. Each call passes `parent: "<EPIC-KEY>"` plus the custom fields via `additional_fields`:

   ```json
   {
     "components": [{"name": "<Component name>"}],
     "customfield_XXXXX": <story_points_number>,
     "customfield_YYYYY": [{"value": "<work-type-option-value>"}]
   }
   ```

   Components is an array even for a single component. Multiselect custom fields (like Work Type in many JIRA configs) take an array of `{value: ...}` objects. Use the **exact** stored option string — see the gotcha in `references/jira-fields.md` about typo'd option values that you must match literally.

6. **Spot-check one ticket** with `getJiraIssue` (request only the fields you set: `summary`, `parent`, `components`, the custom field IDs). Custom field IDs can silently be wrong, so verifying once is worth it before reporting success.
7. **Report.** Summarize as a markdown table of `Key | Title | SP` with each key as a clickable link (`https://<site>.atlassian.net/browse/<KEY>`). Include the total SP and parent epic link. If you noticed any oddities during creation (e.g. typo'd field option values, custom fields that didn't take), surface them — better the user knows now than discovers it next quarter.

## Worked example

A complete example from the original session (*** project, component, Go codebase) is preserved in `references/worked-example.md`. Read it when:

- You want to see a curated table with real entries (TODO inventory → 14 tickets).
- You're unsure how aggressively to filter (the example exclusions show what "too big for a junior" looks like).
- You're working on the same project and want to reuse the field IDs and Components.

## Common failure modes

- **Hardcoding custom-field IDs from a previous project.** Always look them up via `getJiraIssueTypeMetaWithFields`. They differ per JIRA instance and even per project.
- **Sending lowercase/canonical option values when the stored value is typo'd.** Some JIRA option values have stored typos (e.g. `"regular _maintenance"` with a space-underscore). The API rejects normalized strings — use the literal stored value.
- **Creating tickets sequentially.** Use a single message with N parallel `createJiraIssue` calls.
- **Skipping the curation review.** Even if the user said "go", the curated list is a judgment call — show it, get a thumbs up, then create.
- **Letting the scan return a 33-item dump and ticketing all of them.** Curation is the value-add. Tight scope → 10–15 well-scoped tickets is usually right.
- **Forgetting the parent link.** `parent` is a top-level field on `createJiraIssue`, not inside `additional_fields`.
