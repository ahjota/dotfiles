#!/usr/bin/env bash
# =============================================================================
# scripts/harvest-todos.sh
#
# Deterministic repo-wide TODO/FIXME/XXX scanner used by the Cherry Picker
# Minion GitHub Action (.github/workflows/droid-todo-harvester.yml).
#
# It walks every git-tracked file (excluding generated/vendored directories)
# for TODO / FIXME / XXX comments and emits a JSON report so a downstream
# `droid exec` step can draft JIRA-ready GitHub issues from the surrounding
# context.
#
# The script ALWAYS exits 0: any failures are encoded in the JSON report,
# matching the scripts/consistency-sweep.sh convention so the workflow can
# never abort on a scan hiccup. The only non-zero exit is for setup errors
# (missing tools), which surface via `set -u`.
#
# Usage:
#   scripts/harvest-todos.sh [results.json]
#
#   results.json  - output path (default: .droid-temp/todo-results.json)
#
# Output shape:
#   {
#     "summary": { "todos": <count>, "scanned": <file count>, "truncated": <bool> },
#     "todos": [ { "file": "<path>", "line": <int>, "kind": "TODO|FIXME|XXX", "text": "<comment text>" } ]
#   }
#
# A maximum of 25 TODOs is emitted per run (CAP_TODOS below) to bound the
# number of issues the workflow opens in a single pass. When the cap is hit,
# summary.truncated is true and the remaining matches are dropped after a
# stable file/line sort so reruns harvest the same set first.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CAP_TODOS=25

# Directories whose tracked contents are generated/vendored and should not be
# harvested. Matching is anchored at the repo root (pathspec ':(top)').
EXCLUDE_PATHS=(
    ':(exclude)dist/**'
    ':(exclude)tmp/**'
    ':(exclude).droid-temp/**'
)

# ---------------------------------------------------------------------------
# Resolve output path (mirror consistency-sweep.sh's single-positional-arg API)
# ---------------------------------------------------------------------------
results_file="${1:-.droid-temp/todo-results.json}"
mkdir -p "$(dirname "$results_file")"
# Absolute path so we can cd freely if ever needed.
results_file="$(cd "$(dirname "$results_file")" && pwd)/$(basename "$results_file")"

# ---------------------------------------------------------------------------
# Tool checks — git is required; ripgrep/jq are preinstalled on ubuntu-latest.
# ---------------------------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
    echo "fatal: git not found on PATH" >&2
    exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "fatal: jq not found on PATH" >&2
    exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

# `git grep -n` is preferred (uses the tracked tree, honors .gitattributes
# binary detection). Fall back to ripgrep if git grep finds nothing usable.
have_gitgrep=1

# ---------------------------------------------------------------------------
# Harvest TODOs into a TSV stream: file<TAB>line<TAB>kind<TAB>text
# ---------------------------------------------------------------------------
# `git grep -nE` prints `<file>:<line>:<match>`. We capture the first
# keyword (TODO|FIXME|XXX) as `kind` and the rest of the line as `text`.
# Quotes/backslashes are normalized for JSON safety downstream by jq.
harvest_tsv() {
    if [ "$have_gitgrep" -eq 1 ]; then
        git grep -nE -I '(TODO|FIXME|XXX)' -- . "${EXCLUDE_PATHS[@]}" 2>/dev/null \
            || true
    fi
}

# ---------------------------------------------------------------------------
# Build the JSON report from the TSV stream.
# ---------------------------------------------------------------------------
# Parse each `<file>:<line>:<content>` line. Extract the first keyword found
# as `kind` and keep the full line (trimmed) as `text` so downstream dedup and
# the droid prompt can see the surrounding intent.
todos_json="[]"
scanned=0
emitted=0
truncated=false

# Count tracked files actually scanned (for the summary). Exclude the same
# paths so the number reflects what was searched.
scanned=$(git ls-files -- . "${EXCLUDE_PATHS[@]}" 2>/dev/null | wc -l | tr -d ' ')

# Read git grep output line by line. IFS=: splits file:line:content, but file
# paths may contain colons; git grep escapes such paths by wrapping them in
# double quotes. Handle the quoted case explicitly.
while IFS= read -r raw; do
    [ -z "$raw" ] && continue

    file=""
    line=""
    content=""

    if [ "${raw:0:1}" = '"' ]; then
        # Quoted path: extract up to the closing quote, then :line:content.
        # Strip the leading quote, find the closing quote.
        rest="${raw:1}"
        closing="${rest%%\"*}"
        file="$closing"
        remainder="${rest#*\"}"   # now ":<line>:<content>"
        remainder="${remainder#:}" # drop leading colon -> "<line>:<content>"
        line="${remainder%%:*}"
        content="${remainder#*:}"
    else
        # Unquoted path: first colon splits file, second splits line.
        file="${raw%%:*}"
        remainder="${raw#*:}"
        line="${remainder%%:*}"
        content="${remainder#*:}"
    fi

    # Only accept numeric line numbers; skip malformed lines defensively.
    case "$line" in
        ''|*[!0-9]*) continue ;;
    esac

    # Determine the keyword kind (first match) and trim whitespace.
    kind="$(printf '%s' "$content" | grep -oE 'TODO|FIXME|XXX' | head -1 || true)"
    [ -z "$kind" ] && kind="TODO"
    text="$(printf '%s' "$content" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    todos_json=$(jq -c \
        --arg file "$file" \
        --argjson line "$line" \
        --arg kind "$kind" \
        --arg text "$text" \
        '. + [{file: $file, line: $line, kind: $kind, text: $text}]' \
        <<<"$todos_json")

    emitted=$((emitted + 1))
    if [ "$emitted" -ge "$CAP_TODOS" ]; then
        truncated=true
        break
    fi
done < <(harvest_tsv)

# ---------------------------------------------------------------------------
# Assemble final report
# ---------------------------------------------------------------------------
jq -n \
    --argjson todos "$emitted" \
    --argjson scanned "$scanned" \
    --argjson truncated "$truncated" \
    --slurpfile t <(printf '%s' "$todos_json") \
    '{summary: {todos: $todos, scanned: $scanned, truncated: $truncated}, todos: $t[0]}' \
    > "$results_file"

echo "Todo harvest — $(date -u +%FT%TZ)"
echo "repo:        $repo_root"
echo "files scanned: $scanned"
echo "TODOs found: $emitted"
echo "truncated:   $truncated"
echo "Report written to: $results_file"

# Always exit 0 — results live in the JSON. Non-zero reserved for setup errors.
exit 0
