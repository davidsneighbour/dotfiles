#!/bin/bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERBOSE=false
DRY_RUN=false

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--verbose] [--dry-run] [--help]

Add the eza apt repository and install eza.
See https://github.com/eza-community/eza/blob/main/INSTALL.md#debian-and-ubuntu

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
  2. Download https://raw.githubusercontent.com/eza-community/eza/main/deb.asc, dearmor to /etc/apt/keyrings/gierens.gpg
  3. Write /etc/apt/sources.list.d/gierens.list
  4. sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  5. sudo apt update
  6. sudo apt install -y eza
EOF
  exit 0
fi

if [[ "${VERBOSE}" == true ]]; then
  set -x
fi

sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt update
sudo apt install -y eza
