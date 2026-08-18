# shellcheck shell=sh
# 06-work-env.sh — work-only environment variables.
# Sourced by bash and zsh via the ~/.shellrc.d/ loops, so no shebang applies.
# This whole file is gated to work machines only via .chezmoiignore
# (see docs/work-dotfiles.md Pattern 2) — it does not exist on non-work
# machines.

# AJ_FACTORY_DR_TOKEN — API token for wiring Factory to the DataRobot LLM
# gateway. Sourced from `drconfig.yaml`. Silently no-ops if the DR
# CLI hasn't been configured yet or yq isn't installed.
if [ -f "${HOME}/.config/datarobot/drconfig.yaml" ] && command -v yq >/dev/null 2>&1; then
    AJ_FACTORY_DR_TOKEN="$(yq '.token' "${HOME}/.config/datarobot/drconfig.yaml" 2>/dev/null)"
    [ -n "$AJ_FACTORY_DR_TOKEN" ] && [ "$AJ_FACTORY_DR_TOKEN" != "null" ] && export AJ_FACTORY_DR_TOKEN
fi
