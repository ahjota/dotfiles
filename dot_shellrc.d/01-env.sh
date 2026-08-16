# shellcheck shell=sh
# 01-env.sh — shared environment variables for bash and zsh.
# Sourced by both bash and zsh via the ~/.shellrc.d/ loops,
# so no shebang applies.
# Checked against POSIX sh as the restrictive common denominator.

# Root of the user's workspace tree (projects, scratchpads, etc.).
export WORKSPACE="${HOME}/workspace"

# General-purpose scratch directory (throwaway repos, experiments, notes).
# Consumed by the droid wrapper (10-droid.sh) as its default cwd,
# but intentionally not droid-specific. The :- guard lets a machine
# override it earlier (e.g. ~/.profile); always use an absolute path.
export SCRATCHPAD="${SCRATCHPAD:-${HOME}/scratch}"
