# JIRA fields reference

How to discover and set the custom fields this skill cares about. Custom-field IDs are **per-instance and often per-project** — never hardcode them across projects.

## Discovering field IDs

Call `getJiraIssueTypeMetaWithFields` with the project key and the Task issue type ID:

```
getJiraIssueTypeMetaWithFields(
  cloudId=<from getAccessibleAtlassianResources>,
  projectIdOrKey="<KEY>",
  issueTypeId="3"   # 3 is "Task" in default JIRA, but verify via getJiraProjectIssueTypesMetadata
)
```

In the returned `fields` array, look for entries by the human-readable `name`:

| Field name (varies) | What you're looking for |
|---|---|
| `Story Points` | A `number` schema. Note the `customId` — that's the integer; the field key is `customfield_<customId>`. |
| `Work Type` (sometimes "Work Type (test)") | A multiselect with options like `feature_work`, `tech_debt`, `regular _maintenance`, etc. Read `allowedValues` and use the literal `value` string. |
| `Components` | A standard system field, key `components`. Allowed values include the project's component list with `id` and `name`. |

Print or save these IDs once per session — re-discovering for each ticket is wasted tool calls.

## Setting fields on createJiraIssue

The `createJiraIssue` tool uses `additional_fields` for custom fields, plus dedicated args for some system fields:

```json
{
  "cloudId": "<uuid>",
  "projectKey": "CFX",
  "issueTypeName": "Task",
  "parent": "CFX-5928",
  "summary": "...",
  "description": "...",
  "contentFormat": "markdown",
  "additional_fields": {
    "components": [{"name": "DR CLI"}],
    "customfield_10004": 1.5,
    "customfield_19108": [{"value": "regular _maintenance"}]
  }
}
```

Notes:
- **`parent`** sits at the top level, **not** inside `additional_fields`.
- **`components`** is always an array, even for one component. Use `{"name": "..."}` (matching by name is forgiving) or `{"id": "..."}` (by ID, more strict).
- **Story Points** is a `float` field — `0.5` and `1.5` are valid, no need to round to integers.
- **Multiselect custom fields** (like Work Type) take an array of `{value: ...}` objects. Single-select takes a bare object.

## Story Points conversion

Default mapping when the user gives effort in hours and JIRA uses SP:

| Hours estimate | Story Points (2 SP / 8h day = 1 SP / 4h, high end of range) |
|---|---|
| 1–2h | 0.5 |
| 2–3h | 1 |
| 4–6h | 1.5 |
| 6–8h | 2 |
| 1–2 days | 4 |

Use the high end so estimates skew slightly conservative — engineers underestimate more often than they overestimate.

## Gotcha: typo'd option values

JIRA option values can have stored typos that you must match **literally**, not the normalized form you'd expect. The API rejects "corrected" values.

**Example** (real, from CFX project):

The Work Type field has an option whose stored value is `"regular _maintenance"` — note the space before the underscore. Sending `"regular_maintenance"` or `"regular maintenance"` fails. The correct call:

```json
"customfield_19108": [{"value": "regular _maintenance"}]
```

Always paste from `allowedValues[].value` rather than typing.

When you spot something like this, mention it in the final report so the project owner can clean up the field configuration. Don't silently work around it forever.

## Worked example: CFX project (DR CLI)

For reference — fields confirmed in April 2026:

| Setting | Value |
|---|---|
| cloudId | `95d9ca21-14d5-4831-81fb-a55d40bb0b3e` |
| Project key | `CFX` |
| Site URL | `https://datarobot.atlassian.net` |
| Components — DR CLI | `{"name": "DR CLI"}` (id `20366`) |
| Story Points field | `customfield_10004` (float) |
| Work Type field | `customfield_19108` (multiselect, name "Work Type (test)") |
| Work Type — "regular maintenance" option | `[{"value": "regular _maintenance"}]` (note the typo) |
| Work Type — "tech debt" option | `[{"value": "tech_debt"}]` |
| Issue type — Task | id `"3"` |
| Issue type — Epic | id `"10000"` |

Always **re-verify** these via the metadata tools at the start of a fresh session — JIRA admins move things around and the field IDs above could be stale.
