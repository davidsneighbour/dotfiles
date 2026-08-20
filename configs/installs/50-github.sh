#!/bin/bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERBOSE=false
DRY_RUN=false

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--verbose] [--dry-run] [--help]

Add the GitHub CLI apt repository and install gh.

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
  1. Ensure wget is installed
  2. sudo mkdir -p -m 755 /etc/apt/keyrings
  3. Download https://cli.github.com/packages/githubcli-archive-keyring.gpg to /etc/apt/keyrings/githubcli-archive-keyring.gpg
  4. sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  5. sudo mkdir -p -m 755 /etc/apt/sources.list.d
  6. Write /etc/apt/sources.list.d/github-cli.list
  7. sudo apt update
  8. sudo apt install gh -y
EOF
  exit 0
fi

if [[ "${VERBOSE}" == true ]]; then
  set -x
fi

type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)
sudo mkdir -p -m 755 /etc/apt/keyrings

TMP_KEYRING="$(mktemp)"
cleanup() {
  rm -f "${TMP_KEYRING}"
}
trap cleanup EXIT

wget -nv -O "${TMP_KEYRING}" https://cli.github.com/packages/githubcli-archive-keyring.gpg
sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg <"${TMP_KEYRING}" >/dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
sudo mkdir -p -m 755 /etc/apt/sources.list.d
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
sudo apt update
sudo apt install gh -y
