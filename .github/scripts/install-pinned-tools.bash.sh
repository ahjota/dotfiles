#!/usr/bin/env bash
# shellcheck shell=bash
# .github/scripts/install-pinned-tools.bash.sh
# =============================================================================
# Install pinned, checksum-verified releases of the Factory Droid CLI and
# chezmoi for use in CI workflows. Replaces remote `curl | sh` installers
# with version-pinned downloads plus SHA-256 verification.
#
# Usage:
#   install-pinned-tools.bash.sh [droid|chezmoi|all]
#
# The binary is installed to "$HOME/.local/bin" and that directory is appended
# to "$GITHUB_PATH" so subsequent workflow steps can use it.
# =============================================================================
set -euo pipefail

# Pinned versions. Bump these deliberately; the Meter Reader Minion watches
# hardcoded version numbers in scripts.
readonly DROID_VERSION="0.205.0"
readonly CHEZMOI_VERSION="2.72.0"

readonly INSTALL_DIR="${HOME}/.local/bin"

# Global list of temporary directories to remove on exit.
CLEANUP_DIRS=()

# cleanup
# Remove every temporary directory registered in CLEANUP_DIRS.
cleanup() {
  local d
  for d in "${CLEANUP_DIRS[@]}"; do
    if [ -n "$d" ] && [ -d "$d" ]; then
      rm -rf "$d"
    fi
  done
}
trap cleanup EXIT

# register_tmpdir <dir>
# Register a temp directory for cleanup and return its path.
register_tmpdir() {
  local dir="$1"
  CLEANUP_DIRS+=("$dir")
}

# sha256 <file>
# Print the SHA-256 digest of <file> using the best available tool.
sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    echo "Error: neither sha256sum nor shasum is available" >&2
    return 1
  fi
}

# detect_platform -> linux|darwin|windows
# Normalise uname(1) output to the platform names used by the release assets.
detect_platform() {
  local uname_s
  uname_s="$(uname -s)"
  case "$uname_s" in
    Linux)           echo linux ;;
    Darwin)          echo darwin ;;
    MINGW*|CYGWIN*|MSYS*|Windows_NT) echo windows ;;
    *)
      echo "Error: unsupported operating system: $uname_s" >&2
      return 1
      ;;
  esac
}

# detect_arch -> x64|amd64|arm64
# Factory CLI uses "x64" for amd64; chezmoi uses "amd64". We return both
# forms so callers can pick the right one.
detect_arch() {
  local uname_m
  uname_m="$(uname -m)"
  case "$uname_m" in
    x86_64|amd64) echo "x64 amd64" ;;
    arm64|aarch64) echo "arm64 arm64" ;;
    *)
      echo "Error: unsupported architecture: $uname_m" >&2
      return 1
      ;;
  esac
}

# has_avx2 -> true|false
# Used to select the Factory CLI x64 baseline build on CPUs without AVX2.
has_avx2() {
  local platform
  platform="$(detect_platform)"
  case "$platform" in
    linux)
      if [ -r /proc/cpuinfo ] && grep -q -i avx2 /proc/cpuinfo 2>/dev/null; then
        echo true
      else
        echo false
      fi
      ;;
    darwin)
      if sysctl -a 2>/dev/null | grep -q "machdep.cpu.*AVX2"; then
        echo true
      else
        echo false
      fi
      ;;
    *)
      # Windows and other platforms do not have a baseline variant.
      echo true
      ;;
  esac
}

# append_to_github_path <dir>
# Make the installed binary available to later workflow steps.
append_to_github_path() {
  local dir="$1"
  mkdir -p "$dir"
  if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$dir" >> "$GITHUB_PATH"
  fi
}

# install_droid
# Download the pinned Factory CLI release for the current platform, verify
# its SHA-256 digest, and install it to INSTALL_DIR.
install_droid() {
  local platform arch_pair droid_arch arch_suffix
  local binary url sha_url tmp expected actual

  platform="$(detect_platform)"
  arch_pair="$(detect_arch)"
  droid_arch="${arch_pair%% *}"   # x64 or arm64

  arch_suffix=""
  if [ "$platform" != "windows" ] && [ "$droid_arch" = "x64" ]; then
    if [ "$(has_avx2)" = "false" ]; then
      arch_suffix="-baseline"
    fi
  fi

  tmp="$(mktemp -d)"
  register_tmpdir "$tmp"

  if [ "$platform" = "windows" ]; then
    binary="droid.exe"
  else
    binary="droid"
  fi

  url="https://downloads.factory.ai/factory-cli/releases/${DROID_VERSION}/${platform}/${droid_arch}${arch_suffix}/${binary}"
  sha_url="${url}.sha256"

  echo "Installing Factory CLI v${DROID_VERSION} for ${platform}-${droid_arch}${arch_suffix}..."

  curl -fsSL -o "${tmp}/${binary}" "$url"
  curl -fsSL -o "${tmp}/${binary}.sha256" "$sha_url"

  expected="$(awk '{print $1}' "${tmp}/${binary}.sha256")"
  actual="$(sha256 "${tmp}/${binary}")"

  if [ "$expected" != "$actual" ]; then
    echo "Error: Factory CLI checksum mismatch" >&2
    echo "  expected: $expected" >&2
    echo "    actual: $actual" >&2
    return 1
  fi

  echo "Factory CLI checksum verified."

  append_to_github_path "$INSTALL_DIR"
  cp "${tmp}/${binary}" "${INSTALL_DIR}/${binary}"
  chmod +x "${INSTALL_DIR}/${binary}"
}

# install_chezmoi
# Download the pinned chezmoi release archive for the current platform, verify
# its SHA-256 digest against the published checksums.txt, and install the
# chezmoi binary to INSTALL_DIR.
install_chezmoi() {
  local platform arch_pair chezmoi_arch asset url checksums_url tmp
  local extracted_name install_name

  platform="$(detect_platform)"
  arch_pair="$(detect_arch)"
  chezmoi_arch="${arch_pair##* }"  # amd64 or arm64

  if [ "$platform" = "windows" ]; then
    asset="chezmoi_${CHEZMOI_VERSION}_${platform}_${chezmoi_arch}.zip"
  else
    asset="chezmoi_${CHEZMOI_VERSION}_${platform}_${chezmoi_arch}.tar.gz"
  fi

  url="https://github.com/twpayne/chezmoi/releases/download/v${CHEZMOI_VERSION}/${asset}"
  checksums_url="https://github.com/twpayne/chezmoi/releases/download/v${CHEZMOI_VERSION}/chezmoi_${CHEZMOI_VERSION}_checksums.txt"

  tmp="$(mktemp -d)"
  register_tmpdir "$tmp"

  echo "Installing chezmoi v${CHEZMOI_VERSION} for ${platform}-${chezmoi_arch}..."

  curl -fsSL -o "${tmp}/${asset}" "$url"
  curl -fsSL -o "${tmp}/checksums.txt" "$checksums_url"

  # Verify only the line for the asset we downloaded. The checksums.txt
  # format is "<sha256>  <filename>" (two spaces).
  expected="$(awk -v asset="$asset" '$2 == asset {print $1}' "${tmp}/checksums.txt")"
  if [ -z "$expected" ]; then
    echo "Error: could not find checksum for ${asset} in checksums.txt" >&2
    return 1
  fi
  actual="$(sha256 "${tmp}/${asset}")"
  if [ "$expected" != "$actual" ]; then
    echo "Error: chezmoi checksum mismatch" >&2
    echo "  expected: $expected" >&2
    echo "    actual: $actual" >&2
    return 1
  fi

  echo "chezmoi checksum verified."

  if [ "$platform" = "windows" ]; then
    unzip -q -o "${tmp}/${asset}" -d "$tmp"
    extracted_name="chezmoi.exe"
    install_name="chezmoi.exe"
  else
    tar -xzf "${tmp}/${asset}" -C "$tmp"
    extracted_name="chezmoi"
    install_name="chezmoi"
  fi

  append_to_github_path "$INSTALL_DIR"
  cp "${tmp}/${extracted_name}" "${INSTALL_DIR}/${install_name}"
  chmod +x "${INSTALL_DIR}/${install_name}"
}

main() {
  local target="${1:-all}"
  case "$target" in
    droid)   install_droid ;;
    chezmoi) install_chezmoi ;;
    all)     install_droid; install_chezmoi ;;
    *)
      echo "Usage: $0 [droid|chezmoi|all]" >&2
      exit 1
      ;;
  esac
}

main "$@"
