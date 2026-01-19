#!/bin/bash
#
# bash-history-backup.sh
#
# Backup ~/.bash_history (intended for cron @reboot).
#
# Target:
#   ~/log/bash/history/YYYYMMDD-HHMMSS-HOSTNAME.log

set -euo pipefail

#######################################
# Defaults (override via flags)
#######################################
SOURCE_FILE="${HOME}/.bash_history"
BASE_DIR="${HOME}/.logs/bash/history"
VERBOSE=0

#######################################
# Helpers
#######################################
print_help() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --source <path>     Source history file (default: ~/.bash_history)
  --target-dir <dir>  Base backup directory (default: ~/log/bash/history)
  --verbose           Enable verbose output
  --help              Show this help and exit

Description:
  Creates a timestamped backup of the Bash history file.
  Intended to run via cron @reboot.

Examples:
  $(basename "$0")
  $(basename "$0") --verbose
  $(basename "$0") --source "\${HOME}/.bash_history" --target-dir "\${HOME}/log/bash/history"

EOF
}

log() {
  if [ "${VERBOSE}" -eq 1 ]; then
    echo "$@"
  fi
}

fail() {
  echo "Error: $*" 1>&2
  exit 1
}

#######################################
# Argument parsing
#######################################
while [ "$#" -gt 0 ]; do
  case "$1" in
    --source)
      [ "${2:-}" ] || fail "--source requires a value"
      SOURCE_FILE="$2"
      shift 2
      ;;
    --target-dir)
      [ "${2:-}" ] || fail "--target-dir requires a value"
      BASE_DIR="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      fail "Unknown option: $1 (use --help)"
      ;;
  esac
done

#######################################
# Validation
#######################################
[ -f "${SOURCE_FILE}" ] || fail "source file not found: ${SOURCE_FILE}"

#######################################
# Main
#######################################
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
HOSTNAME="$(hostname)"
TARGET_FILE="${BASE_DIR}/${TIMESTAMP}-${HOSTNAME}.log"

log "Source: ${SOURCE_FILE}"
log "Target: ${TARGET_FILE}"

mkdir -p "${BASE_DIR}"
cp "${SOURCE_FILE}" "${TARGET_FILE}"

log "Backup completed successfully."
