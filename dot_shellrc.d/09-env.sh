# 10-env.sh — shared environment variables for bash and zsh.
# Sourced on every interactive shell startup via the ~/.shellrc.d/ loops
# in dot_bashrc.tmpl and dot_zshrc.tmpl. Keep this file POSIX-compatible:
# macOS ships bash 3.2, so no arrays, no zsh-isms.

# Root of the user's workspace tree (projects, scratchpads, etc.).
export WORKSPACE="${HOME}/workspace"
