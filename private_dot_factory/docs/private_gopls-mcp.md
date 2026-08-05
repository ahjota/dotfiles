# gopls MCP Tool Usage

When the gopls MCP server is connected, prefer its semantic tools over
lexical `grep` for Go symbol-level work. These tools are type-aware and
avoid the false-positive problem of generic method names (e.g. `.Run()`,
`.Get()`, `.Close()`) matching stdlib and unrelated packages.

**Context discipline is critical.** gopls tools can return large amounts
of output. Scope every query to what the task needs; do not run
workspace-wide operations for targeted edits.

## Session start

If the session environment already indicates a Go module (presence of
`go.mod`, `go.sum`), you may skip `go_workspace`. Run it only when the
project layout is unclear (workspace files, GOPATH, multi-module).

Run `go_vulncheck` **only** when your edits add or update dependencies in
`go.mod`. Do not run it unconditionally at session start — its output is
large and usually irrelevant to the task.

## Read workflow

Follow these steps when investigating Go code. Re-do any step as needed
to recover from errors.

1. **Find relevant symbols**: Use `go_search` to locate types,
   functions, or variables by fuzzy name. It is capped at 100 results
   and context-cheap.
   ```jsonc
   go_search({"query":"engine"})
   ```

2. **Understand a file's intra-package dependencies**: Use
   `go_file_context` when you need to know how a file connects to other
   files *in the same package*. Use it after first reading a Go file
   **only when the task requires understanding intra-package
   relationships** — skip it for surgical single-symbol edits where you
   already know what you're looking for.
   ```jsonc
   go_file_context({"file":"/path/to/engine.go"})
   ```

3. **Understand a package's public API**: Use `go_package_api` to learn
   what a package exports to external callers, especially for
   third-party dependencies or other packages in the monorepo.
   ```jsonc
   go_package_api({"packagePaths":["github.com/datarobot/cli/internal/workload/wapi"]})
   ```

## Edit workflow

The edit workflow is iterative. Cycle through these steps until the task
is complete. Do not skip steps.

1. **Read first**: Follow the Read Workflow to understand the relevant
   code before editing.

2. **Find references**: Before modifying the definition of any symbol,
   use `go_symbol_references` to find all references. Read the files
   containing references to evaluate whether further edits are required.
   ```jsonc
   go_symbol_references({"file":"/path/to/engine.go","symbol":"Engine.Run"})
   ```

3. **Make edits**: Apply the required edits, including edits to
   references identified in the previous step. Complete all planned
   edits before proceeding.

4. **Check for errors**: After every code modification, call
   `go_diagnostics` with the paths of the files you edited. For a
   single file, `getIdeDiagnostics` (the VS Code IDE bridge) is cheaper
   and reflects live editor state — prefer it when you only need one
   file. Use `go_diagnostics` when you need multiple files.
   ```jsonc
   go_diagnostics({"files":["/path/to/engine.go","/path/to/engine_test.go"]})
   ```

5. **Fix errors**: If diagnostics report errors, fix them. The tool may
   provide suggested quick fixes as diffs — review and apply them if
   correct, then re-run diagnostics to confirm. It is OK to ignore
   `hint` or `info` diagnostics when irrelevant to the task. Note: Go
   diagnostic messages may contain a summary of the source code that
   does not match its exact text.

6. **Check for vulnerabilities**: If your edits added or updated
   dependencies in `go.mod`, run `go_vulncheck` across the workspace.
   Skip this step otherwise.
   ```jsonc
   go_vulncheck({"pattern":"./..."})
   ```

7. **Run tests**: Once diagnostics report no errors (and only then), run
   tests for the packages you changed. Do not run `go test ./...` unless
   explicitly requested.
   ```bash
   go test ./internal/workload/sync/...
   ```

## Renaming a symbol

`go_rename_symbol` returns a diff of the required changes but **does not
apply them to disk**. Treat it as a planning tool:

1. Call `go_rename_symbol` to get the complete diff.
   ```jsonc
   go_rename_symbol({"file":"/path/to/engine.go","symbol":"Engine.Run","new_name":"Sync"})
   ```

2. Apply the returned edits with `Edit` calls.

3. **Update coupled text the tool misses**: `go_rename_symbol` does not
   rename doc comments, type-level comments, or test function names that
   embed the old symbol. After applying the rename, search for the old
   name in comments and `Test..._OldName...` test identifiers and update
   them manually.

4. **Verify**: Run `go_symbol_references` on the new symbol name to
   confirm no stray old-name callers remain.

## gopls vs grep

| Task | Tool |
| --- | --- |
| Find all callers of a specific symbol | `go_symbol_references` |
| Fuzzy-find a symbol by name | `go_search` |
| Diagnostics for edited Go files | `go_diagnostics` or `getIdeDiagnostics` |
| Search for a literal string, comment, flag name, or pattern | `grep` / `Grep` |
| Search across non-Go files | `grep` / `Grep` |
| Rename a Go symbol | `go_rename_symbol` + `Edit` |

When a method name is generic and collides with stdlib (`.Run()`,
`.Close()`), `grep` produces many false positives. Use
`go_symbol_references` to get the type-aware answer in one call.

## Recovering from stale gopls state

If a gopls tool fails with a "file has errors" message that
`getIdeDiagnostics` or `go_diagnostics` contradicts, the gopls index is
stale from recent manual edits. Retry the operation — it typically
settles on the second call. Do not diagnose the phantom error; confirm
diagnostics are clean and retry.
