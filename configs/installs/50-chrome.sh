#!/bin/bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERBOSE=false
DRY_RUN=false

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--verbose] [--dry-run] [--help]

Download and install the latest Google Chrome stable .deb package.

Options:
  --verbose   Trace each command as it runs.
  --dry-run   Print what would run without downloading or installing anything.
  --help      Show this help.
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
  cat <<'EOF'
Would run:
  1. Download https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb to a temp file
  2. sudo dpkg -i <temp file>
  3. sudo apt install -f -y
  4. Remove the temp file
EOF
  exit 0
fi

if [[ "${VERBOSE}" == true ]]; then
  set -x
fi

TMP_DEB="$(mktemp --suffix=.deb)"
cleanup() {
  rm -f "${TMP_DEB}"
}
trap cleanup EXIT

wget -O "${TMP_DEB}" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
sudo dpkg -i "${TMP_DEB}"
sudo apt install -f -y
