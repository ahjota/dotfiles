#!/usr/bin/env bash
# shellcheck shell=bash
# consistency-sweep.sh — headless dotfile consistency sweep.
#
# Runs every static check listed in issue #137 across the whole chezmoi source
# tree and emits a machine-readable JSON report of *all* failures. The script
# never exits non-zero on a check failure — failures are encoded in the JSON so
# a downstream CI step can open one GitHub issue per failing file (or a single
# summary issue). It only exits non-zero on an internal/setup error.
#
# Checks performed:
#   1. shellcheck on every tracked *.sh file (dialect inferred from name).
#   2. `chezmoi execute-template` render of every tracked *.tmpl file.
#   3. `bash -n` syntax check on rendered bash templates + *.sh bash files.
#   4. `zsh -n`  syntax check on rendered zsh templates (skipped, not failed,
#      when zsh is unavailable — e.g. on a runner without zsh).
#
# Usage:
#   scripts/consistency-sweep.sh [results.json]
#
# Environment:
#   CHEZMOI_CI_CONFIG — path to a non-interactive chezmoi config. Required for
#                       template rendering; without it every .tmpl render is
#                       recorded as a failure with a clear message.
#   SHELLCHECK_SEVERITY — minimum severity to report (default: warning).

set -uo pipefail

shellcheck_severity="${SHELLCHECK_SEVERITY:-warning}"
results_file="${1:-$(mktemp -t consistency-sweep-results.XXXXXX.json)}"

# Resolve repo root so the script works from any working directory.
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root" || exit 1

# Temporary scratch space for rendered templates. Cleaned up on exit.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

chezmoi_config="${CHEZMOI_CI_CONFIG:-}"
have_chezmoi=0
have_shellcheck=0
have_bash=0
have_zsh=0
command -v chezmoi    >/dev/null 2>&1 && have_chezmoi=1
command -v shellcheck >/dev/null 2>&1 && have_shellcheck=1
command -v bash       >/dev/null 2>&1 && have_bash=1
command -v zsh        >/dev/null 2>&1 && have_zsh=1

# Build the JSON failure array incrementally with jq. Start empty and append.
failures_file="$tmpdir/failures.json"
echo '[]' > "$failures_file"

# add_failure <file> <check> <output>
# Append one failure record. `output` is read from stdin so multi-line check
# output (including quotes/newlines) is safely JSON-encoded by jq.
add_failure() {
    local file="$1" check="$2" output
    output="$(cat)"
    jq --arg file "$file" --arg check "$check" --arg output "$output" \
        '. + [{file: $file, check: $check, output: $output}]' \
        "$failures_file" > "$failures_file.tmp" && mv "$failures_file.tmp" "$failures_file"
}

# run_check <file> <check> <cmd...>
# Run a command, capturing combined stdout+stderr. On non-zero exit, record a
# failure. A zero exit with non-empty shellcheck output (warnings at the chosen
# severity) is also treated as a failure so findings surface as issues.
run_check() {
    local file="$1" check="$2"; shift 2
    local out rc
    out="$("$@" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 0 ]; then
        printf '%s' "$out" | add_failure "$file" "$check"
    elif [ "$check" = "shellcheck" ] && [ -n "$out" ]; then
        # The linter returns 0 but prints findings at the configured severity;
        # treat any non-empty output as a failure so findings become issues.
        printf '%s' "$out" | add_failure "$file" "$check"
    fi
}

# render <tmpl> -> stdout  (failures recorded by the caller via run_check)
render() {
    local tmpl="$1"
    if [ "$have_chezmoi" -ne 1 ]; then
        echo "chezmoi not found on PATH" >&2
        return 127
    fi
    if [ -z "$chezmoi_config" ]; then
        echo "CHEZMOI_CI_CONFIG is unset; cannot render templates headlessly" >&2
        return 2
    fi
    chezmoi execute-template --config "$chezmoi_config" < "$tmpl"
}

# Infer the shellcheck dialect of a tracked *.sh file.
#
# Detection order:
#   1. # shellcheck shell=<dialect> directive in the first 5 lines
#   2. shebang interpreter (bash -> bash, anything else -> sh)
#   3. filename heuristic (*bash* -> bash, else sh)
dialect_of() {
    local file="$1"
    local dialect shebang_shell

    # 1. Explicit shellcheck directive.
    dialect="$(head -n 5 "$file" | sed -n 's/^[[:space:]]*# shellcheck shell=\([a-zA-Z0-9_]*\).*/\1/p' | head -n 1)"
    if [ -n "$dialect" ]; then
        echo "$dialect"
        return 0
    fi

    # 2. Shebang interpreter (last token of the #! line).
    shebang_shell="$(head -n 1 "$file" | awk '{print $NF}')"
    case "$shebang_shell" in
        */bash|bash)
            echo bash
            return 0
            ;;
    esac

    # 3. Filename fallback.
    case "$file" in
        *bash*) echo bash ;;
        *)      echo sh   ;;
    esac
}

# Classify a *.tmpl file by target shell. Returns "bash", "zsh", "sh", or "".
# An empty result means the template is not a shell file (e.g. dot_Rprofile.tmpl
# is R, dot_gitconfig.tmpl is git INI) — only the render check applies to it.
#
# dot_profile.tmpl is matched explicitly (not via a *profile* glob) so that
# dot_Rprofile.tmpl is not mistaken for a POSIX sh template.
shell_kind_of_template() {
    local base="$1"
    case "$base" in
        *bash*)                echo bash ;;
        *zsh*)                 echo zsh  ;;
        *.sh.tmpl|dot_profile.tmpl) echo sh  ;;
        *)                     echo ""   ;;
    esac
}

echo "Consistency sweep — $(date -u +%FT%TZ)"
echo "repo:        $repo_root"
echo "chezmoi:     ${have_chezmoi:+yes}${have_chezmoi:-missing}  shellcheck: ${have_shellcheck:+yes}${have_shellcheck:-missing}"
echo "bash:        ${have_bash:+yes}${have_bash:-missing}  zsh:        ${have_zsh:+yes}${have_zsh:-missing}"
echo "config:      ${chezmoi_config:-<unset>}"
echo "severity:    $shellcheck_severity"
echo

# ---------------------------------------------------------------------------
# 1. shellcheck + bash -n on tracked *.sh files
# ---------------------------------------------------------------------------
sh_files="$(git ls-files '*.sh')"
files_checked=0
if [ -n "$sh_files" ]; then
    for f in $sh_files; do
        files_checked=$((files_checked + 1))
        d="$(dialect_of "$f")"
        if [ "$have_shellcheck" -eq 1 ]; then
            run_check "$f" "shellcheck" shellcheck --severity="$shellcheck_severity" -s "$d" "$f"
        fi
        if [ "$d" = bash ] && [ "$have_bash" -eq 1 ]; then
            run_check "$f" "bash -n" bash -n "$f"
        fi
    done
else
    echo "No tracked *.sh files found."
fi

# ---------------------------------------------------------------------------
# 2-4. Render every tracked *.tmpl, then shellcheck / bash -n / zsh -n
#      according to the template's target shell (inferred from name).
# ---------------------------------------------------------------------------
tmpl_files="$(git ls-files '*.tmpl')"
if [ -n "$tmpl_files" ]; then
    for t in $tmpl_files; do
        files_checked=$((files_checked + 1))

        # .chezmoi.toml.tmpl uses promptStringOnce/promptBoolOnce, which are
        # only defined during `chezmoi init` — `chezmoi execute-template` (run
        # standalone) errors with `function "promptStringOnce" not defined`.
        # Skip it with a note; this matches scripts/lint-shell-templates.sh.
        if [ "$t" = ".chezmoi.toml.tmpl" ]; then
            echo "skip: .chezmoi.toml.tmpl requires chezmoi init (promptOnce funcs); execute-template cannot render it standalone"
            continue
        fi

        # Render to a scratch file so syntax-check tools can read it.
        rendered="$tmpdir/$(basename "$t")"
        if render "$t" > "$rendered" 2>"$tmpdir/render.err"; then
            : # rendered ok
        else
            cat "$tmpdir/render.err" | add_failure "$t" "chezmoi execute-template"
            continue  # cannot lint an unrenderable template
        fi

        kind="$(shell_kind_of_template "$(basename "$t")")"
        case "$kind" in
            bash)
                if [ "$have_shellcheck" -eq 1 ]; then
                    run_check "$t" "shellcheck" shellcheck --severity="$shellcheck_severity" -s bash "$rendered"
                fi
                if [ "$have_bash" -eq 1 ]; then
                    run_check "$t" "bash -n" bash -n "$rendered"
                fi
                ;;
            zsh)
                if [ "$have_shellcheck" -eq 1 ]; then
                    # No native zsh dialect; run as sh to catch cross-shell
                    # issues, but record under a distinct check name so the
                    # issue body is accurate.
                    run_check "$t" "shellcheck(sh)" shellcheck --severity="$shellcheck_severity" -s sh "$rendered"
                fi
                if [ "$have_zsh" -eq 1 ]; then
                    run_check "$t" "zsh -n" zsh -n "$rendered"
                else
                    echo "skip: zsh not found; skipping zsh -n for $t"
                fi
                ;;
            sh)
                if [ "$have_shellcheck" -eq 1 ]; then
                    run_check "$t" "shellcheck" shellcheck --severity="$shellcheck_severity" -s sh "$rendered"
                fi
                ;;
            "")
                # Non-shell template (R, git INI, etc.) — render check only.
                ;;
        esac
    done
else
    echo "No tracked *.tmpl files found."
fi

# ---------------------------------------------------------------------------
# Assemble final report
# ---------------------------------------------------------------------------
failures_count="$(jq 'length' "$failures_file")"
jq -n \
    --argjson failures "$failures_count" \
    --argjson files "$files_checked" \
    --slurpfile f "$failures_file" \
    '{summary: {files_checked: $files, failures: $failures}, failures: $f[0]}' \
    > "$results_file"

echo
echo "Sweep complete: $files_checked file(s) checked, $failures_count failure(s)."
echo "Report written to: $results_file"

# Always exit 0 — failures live in the JSON. Non-zero is reserved for setup
# errors (which would have aborted earlier via `set -u`/missing-tool checks).
exit 0
