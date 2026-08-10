# 01-env.sh — shared environment variables for bash and zsh.
# Sourced on every interactive shell startup via the ~/.shellrc.d/ loops
# in dot_bashrc.tmpl and dot_zshrc.tmpl. Keep this file POSIX-compatible.

# Root of the user's workspace tree (projects, scratchpads, etc.).
export WORKSPACE="${HOME}/workspace"

# General-purpose scratch directory (throwaway repos, experiments, notes).
# Consumed by the droid wrapper (10-droid-bash*.sh) as its default cwd,
# but intentionally not droid-specific. The :- guard lets a machine
# override it earlier (e.g. ~/.profile); always use an absolute path.
export SCRATCHPAD="${SCRATCHPAD:-${HOME}/scratch}"
