#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<USAGE
Usage:
  ${SCRIPT_NAME} --id <identifier> [--prio <1|2|3>] [--label <text>] [--description <text>] [--file <path>] [--log-file <path>] [--verbose]
  ${SCRIPT_NAME} --help
USAGE
}

if [[ "$#" -eq 0 || "${1:-}" == '--help' ]]; then
  usage
  exit 0
fi

if [[ -n "${BASHRC_PATH:-}" ]]; then
  # shellcheck disable=SC1091
  source "${BASHRC_PATH}/lib/45-workspace/issues.bash"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  DOTFILES_PATH="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
  # shellcheck disable=SC1091
  source "${DOTFILES_PATH}/bashrc/lib/45-workspace/issues.bash"
fi

dnb_polybar_issue_add "$@"
