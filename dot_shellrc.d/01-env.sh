# 01-env.sh — shared environment variables for bash and zsh.
# Sourced on every interactive shell startup via the ~/.shellrc.d/ loops
# in dot_bashrc.tmpl and dot_zshrc.tmpl. Keep this file POSIX-compatible.

# Root of the user's workspace tree (projects, scratchpads, etc.).
export WORKSPACE="${HOME}/workspace"

# General-purpose scratch directory (throwaway repos, experiments, notes).
# Consumed by the droid wrapper (10-droid.sh) as its default cwd,
# but intentionally not droid-specific. The :- guard lets a machine
# override it earlier (e.g. ~/.profile); always use an absolute path.
export SCRATCHPAD="${SCRATCHPAD:-${HOME}/scratch}"

# PATH bootstrap — prepend $HOME/.local/bin and $HOME/bin so both bash
# and zsh sessions (including the bash -> zsh handoff path, which never
# reaches dot_bashrc.tmpl) start with the user-local bins available.
# POSIX `case` keeps the file portable across bash 3.2 and zsh 5.x
# without depending on bash's [[ =~ ]] regex match. Idempotent: reruns
# are no-ops when the directory is already on PATH.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac
case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) PATH="$HOME/bin:$PATH" ;;
esac
export PATH
