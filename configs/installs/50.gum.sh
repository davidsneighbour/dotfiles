#!/bin/bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERBOSE=false
DRY_RUN=false

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--verbose] [--dry-run] [--help]

Add the Charm apt repository and install gum.

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
  1. sudo mkdir -p /etc/apt/keyrings
  2. Download https://repo.charm.sh/apt/gpg.key, dearmor to /etc/apt/keyrings/charm.gpg
  3. Write /etc/apt/sources.list.d/charm.list
  4. sudo apt update && sudo apt install gum -y
EOF
  exit 0
fi

if [[ "${VERBOSE}" == true ]]; then
  set -x
fi

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update
sudo apt install gum -y
