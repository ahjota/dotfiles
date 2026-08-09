# ~/.bashrc.d/droid.sh
# Smart droid wrapper: redirects to nearest trusted folder (or ~/scratch),
# unless running a subcommand or an explicit --cwd is given.

# Known subcommands that should NOT be redirected (always run in CWD)
_droid_subcommands="exec daemon search find update mcp plugin computer help"

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
    local sub
    for sub in $_droid_subcommands; do
        if [[ "$first_positional" == "$sub" ]]; then
            command droid "$@"
            return $?
        fi
    done

    # 3. Read trusted folders from settings.json (canonical paths via realpath)
    declare -A _trusted=()
    if [[ -f "$HOME/.factory/settings.json" ]]; then
        local t
        while IFS= read -r t; do
            [[ -z "$t" ]] && continue
            local rt
            rt=$(realpath "$t" 2>/dev/null || echo "$t")
            _trusted["$rt"]=1
        done < <(jq -r '.trustedFolders | keys[]?' "$HOME/.factory/settings.json" 2>/dev/null)
    fi

    # 4. Walk up from PWD to find nearest trusted ancestor
    local target=""
    local dir
    dir=$(realpath "$PWD" 2>/dev/null || echo "$PWD")
    while [[ -n "$dir" && "$dir" != "/" ]]; do
        if [[ -n "${_trusted[$dir]+x}" ]]; then
            target="$dir"
            break
        fi
        dir=$(dirname "$dir")
    done

    # 5. No trusted ancestor → default to ~/scratch
    if [[ -z "$target" ]]; then
        target=$(realpath "$HOME/scratch" 2>/dev/null || echo "$HOME/scratch")
    fi

    command droid --cwd "$target" "$@"
}

droid()      { _droid_smart "$@"; }
dr()         { _droid_smart "$@"; }
droid-here() { command droid "$@"; }
