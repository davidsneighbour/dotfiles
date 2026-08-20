#!/bin/bash
set -euo pipefail

# NOTE: These instructions only work for 64-bit Debian-based
# Linux distributions such as Ubuntu, Mint etc.

SCRIPT_NAME="$(basename "$0")"
VERBOSE=false
DRY_RUN=false

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--verbose] [--dry-run] [--help]

Add the Signal Desktop apt repository and install signal-desktop.

Options:
  --verbose   Trace each command as it runs.
  --dry-run   Print what would run without changing anything.
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
  1. Download https://updates.signal.org/desktop/apt/keys.asc, dearmor to /usr/share/keyrings/signal-desktop-keyring.gpg
  2. Download https://updates.signal.org/static/desktop/apt/signal-desktop.sources to /etc/apt/sources.list.d/signal-desktop.sources
  3. sudo apt update && sudo apt install -y signal-desktop
EOF
  exit 0
fi

if [[ "${VERBOSE}" == true ]]; then
  set -x
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

# 1. Install our official public software signing key:
wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor >"${TMP_DIR}/signal-desktop-keyring.gpg"
sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg <"${TMP_DIR}/signal-desktop-keyring.gpg" >/dev/null

# 2. Add our repository to your list of repositories:
wget -O "${TMP_DIR}/signal-desktop.sources" https://updates.signal.org/static/desktop/apt/signal-desktop.sources
sudo tee /etc/apt/sources.list.d/signal-desktop.sources <"${TMP_DIR}/signal-desktop.sources" >/dev/null

# 3. Update your package database and install Signal:
sudo apt update
sudo apt install -y signal-desktop
