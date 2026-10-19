#!/usr/bin/env bash
# shellcheck shell=bash
# lint-shell-templates.sh — render chezmoi shell templates and lint them.
#
# Chezmoi templates contain Go template syntax, so shellcheck cannot read
# them directly. This script renders each template with a non-interactive
# chezmoi config and runs shellcheck (bash/sh templates) or zsh -n
# (zsh templates) on the rendered output.
#
# Usage:
#   ./scripts/lint-shell-templates.sh
#
# Environment:
#   SHELLCHECK_SEVERITY — minimum severity to fail on (default: warning).
#                         Set to "error" to ignore warnings/info, or "info"
#                         to fail on everything.

set -euo pipefail

shellcheck_severity="${SHELLCHECK_SEVERITY:-warning}"

# Resolve repo root so the script can be run from any working directory.
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

# Temporary directory for the non-interactive chezmoi config and rendered files.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Non-interactive config with dummy values for every promptBoolOnce /
# promptStringOnce field used by .chezmoi.toml.tmpl. This lets
# execute-template run without blocking for input.
cat > "$tmpdir/chezmoi.toml" <<'EOF'
[data]
email = "lint@example.com"
work = false
iterm2 = false
artifactoryHost = ""
bashMajor = 5

[data.dev]
java = false

[data.fonts]
sans-serif = '"Helvetica",sans-serif'
serif = '"Georgia",serif'
mono = '"Fira Code Mono"'
EOF

chezmoi_config="$tmpdir/chezmoi.toml"

# Render a chezmoi template to stdout using the non-interactive config.
# --source "$repo_root" ensures include directives resolve against the
# repository's source tree rather than the default chezmoi source directory.
render_template() {
    local tmpl="$1"
    chezmoi execute-template --config "$chezmoi_config" --source "$repo_root" < "$tmpl"
}

# Lint a rendered bash template with shellcheck.
lint_bash_template() {
    local tmpl="$1"
    echo "=== $tmpl (bash) ==="
    render_template "$tmpl" | shellcheck --severity="$shellcheck_severity" -s bash -
}

# Lint a rendered POSIX sh template with shellcheck.
lint_sh_template() {
    local tmpl="$1"
    echo "=== $tmpl (sh) ==="
    render_template "$tmpl" | shellcheck --severity="$shellcheck_severity" -s sh -
}

# Lint a rendered zsh template with zsh -n (shellcheck does not support zsh).
lint_zsh_template() {
    local tmpl="$1"
    local rendered
    rendered="$tmpdir/$(basename "$tmpl" .tmpl)"
    echo "=== $tmpl (zsh) ==="
    render_template "$tmpl" > "$rendered"
    if command -v zsh >/dev/null 2>&1; then
        zsh -n "$rendered"
    else
        echo "warning: zsh not found; skipping zsh syntax check for $tmpl" >&2
    fi
}

# Lint non-template shell files directly.
lint_shellrc_d() {
    echo "=== dot_shellrc.d/*.sh ==="
    shellcheck --severity="$shellcheck_severity" dot_shellrc.d/*.sh
}

lint_sh_template dot_profile.tmpl
lint_bash_template dot_bash_profile.tmpl
lint_bash_template dot_bashrc.tmpl
lint_zsh_template dot_zshrc.tmpl
lint_shellrc_d

echo ""
echo "All shell templates passed linting."
