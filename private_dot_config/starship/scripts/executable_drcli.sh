#!/bin/sh
set -eu

# Emit the DataRobot CLI version, or exit non-zero if `dr` is not the
# DataRobot CLI (e.g. a different `dr` binary/symlink is on PATH).
version=$(dr self version --short 2>/dev/null)

case "$version" in
  v[0-9]*.[0-9]*)
    printf '%s\n' "$version"
    ;;
  *)
    exit 1
    ;;
esac
