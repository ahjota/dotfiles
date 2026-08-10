# ~/.shellrc.d/10-droid-bash3.sh — bash 3.2 variant of the droid wrapper.
#
# Deployed by chezmoi only on hosts whose bash predates 4.0 (e.g. macOS,
# which ships /bin/bash 3.2); the bash 4.0+ sibling 10-droid-bash4.sh is
# deployed elsewhere. Selection is driven by data.bashMajor (set at
# `chezmoi init` time) via .chezmoiignore; see issue #81.
#
# bash 3.2 lacks associative arrays, so trusted folders are kept as a
# newline-delimited list with a linear membership scan (the list is tiny).
# This file is also sourced by zsh on macOS (via the ~/.shellrc.d loop in
# ~/.zshrc), so it avoids two zsh pitfalls as well:
#   - no `for x in $unquoted_list` iteration (zsh does not word-split
#     unquoted variables, so such loops see the whole string at once)
#   - locals are declared once, outside loops (redeclaring an existing
#     local makes zsh's typeset print "name=value" on every iteration)
#
# Smart droid wrapper: redirects to nearest trusted folder (or $SCRATCHPAD),
# unless running a subcommand or an explicit --cwd is given.

# Known subcommands that should NOT be redirected (always run in CWD)
_droid_subcommands="exec daemon search find update mcp plugin computer help"

# _droid_trusted_contains NEEDLE LIST — return 0 if NEEDLE is one of the
# newline-delimited entries of LIST. Whole-string comparison, so there are
# no associative-array subscript quoting differences between bash and zsh.
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

    # 2. If first positional arg is a subcommand, pass through (no redirect)
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
    # $WORKSPACE/scratch); the inline fallback keeps this file sane even
    # if it is ever sourced without 01-env.sh.
    if [[ -z "$target" ]]; then
        target=${SCRATCHPAD:-$HOME/workspace/scratch}
    fi

    command droid --cwd "$target" "$@"
}

droid()      { _droid_smart "$@"; }
dr()         { _droid_smart "$@"; }
droid-here() { command droid "$@"; }
