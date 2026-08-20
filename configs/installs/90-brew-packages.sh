#!/bin/bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERBOSE=false
DRY_RUN=false

BREW_PACKAGES=(
  gum
  biome
  lychee
  llmfit
  osv-scanner
  snitch
  typos-cli
  yamllint
  sass/sass/sass
  shellcheck
  zizmor
)

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--verbose] [--dry-run] [--help]

Tap dart-lang/dart and install the shared Homebrew CLI tool set:
${BREW_PACKAGES[*]}

Options:
  --verbose   Trace each command as it runs.
  --dry-run   Print what would run without changing anything.
  --help      Show this help.

Note: do not install gemini-cli via brew, it messes up nvm.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
  --verbose)
    VERBOSE=true
    shift
    ;;
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  --help)
    print_help
    exit 0
    ;;
  *)
    echo "Unknown argument: ${1}" >&2
    print_help >&2
    exit 1
    ;;
  esac
done

if [[ "${DRY_RUN}" == true ]]; then
  cat <<EOF
Would run:
  1. brew tap dart-lang/dart
  2. brew trust dart-lang/dart
  3. brew install ${BREW_PACKAGES[*]}
EOF
  exit 0
fi

if [[ "${VERBOSE}" == true ]]; then
  set -x
fi

brew tap dart-lang/dart
brew trust dart-lang/dart
brew install "${BREW_PACKAGES[@]}"
