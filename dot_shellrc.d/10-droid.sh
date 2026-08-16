# shellcheck shell=bash
# ~/.shellrc.d/10-droid.sh — unified droid wrapper.
# Sourced by both bash and zsh (never executed), so no shebang; checked
# against bash as the restrictive common denominator.
#
# Smart droid wrapper: redirects to nearest trusted folder (or $SCRATCHPAD),
# unless running a subcommand or an explicit --cwd is given.
#
# Deployed on every host (bash or zsh, any version).
# Portable to bash 3.2, bash 4+, and zsh 5.x.
#
# Portable idioms used here:
#   - Subcommand membership via case pattern on a space-padded literal,
#     NOT `for sub in $unquoted_list` (zsh does not word-split unquoted
#     variables, so that loop sees the whole string at once and never
#     matches).
#   - Trusted folders stored as a single newline-delimited string, with
#     linear membership scan in a while-read loop. Cheaper than
#     associative arrays for the typical 0-3 folder list and entirely
#     shell-portable.
#   - Locals are declared once outside loops; re-declaring an existing
#     local makes zsh's typeset print "name=value" on every iteration.

# Known subcommands that should NOT be redirected (always run in CWD).
# Stored as a literal space-separated string; the case pattern below does
# membership via padding, which works the same in bash and zsh without
# relying on either shell's word-splitting behavior.
_droid_subcommands="exec daemon search find update mcp plugin computer help"

# _droid_trusted_contains NEEDLE LIST — return 0 if NEEDLE is one of the
# newline-delimited entries of LIST. Whole-string comparison, linear scan.
# Reminder: don't build an associative array for this unless you drop
# support for bash 3.2 AND zsh gets its act together.
_droid_trusted_contains() {
    local needle=$1
    local list=$2
    local line
    while IFS= read -r line; do
        [[ "$line" == "$needle" ]] && return 0
    done <<< "$list"
    return 1
}

_droid_smart() {
    # 1. If user explicitly passed --cwd, pass through untouched
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "--cwd" || "$arg" == --cwd=* ]]; then
            command droid "$@"
            return $?
        fi
    done

    # 2. If first positional arg is a subcommand, pass through (no redirect).
    # Identify the first non-flag positional argument; flags like --verbose
    # are skipped so a subcommand after flags (e.g. `droid --quiet exec ...`)
    # is still detected as a subcommand and passes through unwrapped.
    local first_positional=""
    for arg in "$@"; do
        if [[ "$arg" != -* ]]; then
            first_positional="$arg"
            break
        fi
    done
    # Word-list membership via case: portable across bash 3.2, bash 4+,
    # and zsh. zsh does not word-split unquoted variables, so the naive
    # `for sub in $_droid_subcommands` compares the whole string once and
    # never matches. Quoted expansion in the pattern stays literal, so a
    # first_positional containing glob characters cannot false-match.
    case " $_droid_subcommands " in
        *" $first_positional "*)
            command droid "$@"
            return $?
            ;;
    esac

    # 3. Read trusted folders from settings.json into a newline-delimited
    # list (canonical paths via realpath when available; stock macOS lacks
    # realpath, in which case paths are compared as written).
    local t rt
    local trusted_list=""
    if [[ -f "$HOME/.factory/settings.json" ]]; then
        while IFS= read -r t; do
            [[ -z "$t" ]] && continue
            rt=$(realpath "$t" 2>/dev/null || echo "$t")
            trusted_list="${trusted_list}${rt}"$'\n'
        done < <(jq -r '.trustedFolders | keys[]?' "$HOME/.factory/settings.json" 2>/dev/null)
    fi

    # 4. Walk up from PWD to find nearest trusted ancestor
    local target=""
    local dir
    dir=$(realpath "$PWD" 2>/dev/null || echo "$PWD")
    while [[ -n "$dir" && "$dir" != "/" ]]; do
        if _droid_trusted_contains "$dir" "$trusted_list"; then
            target="$dir"
            break
        fi
        dir=$(dirname "$dir")
    done

    # 5. No trusted ancestor → default to the scratchpad.
    # SCRATCHPAD is exported by ~/.shellrc.d/01-env.sh (default:
    # $HOME/scratch); the inline fallback keeps this file sane even
    # if it is ever sourced without 01-env.sh.
    if [[ -z "$target" ]]; then
        target=${SCRATCHPAD:-$HOME/scratch}
    fi

    command droid --cwd "$target" "$@"
}

droid()      { _droid_smart "$@"; }
dr()         { _droid_smart "$@"; }
droid-here() { command droid "$@"; }
