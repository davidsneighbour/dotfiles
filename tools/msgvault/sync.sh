#!/bin/bash

set -uo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin"

SCRIPT_NAME="$(basename "${0}")"

LOG_BASE_DIR="${HOME}/.logs/msgvault"
LOG_FILE="${LOG_BASE_DIR}/sync-$(date +%Y%m%d).log"
MSGVAULT_BIN="${HOME}/.local/bin/msgvault"
POLYBAR_ISSUES_FILE="${DNB_POLYBAR_ISSUES_FILE:-${HOME}/.config/polybar/issues.toml}"
POLYBAR_ISSUE_ID="${DNB_MSGVAULT_POLYBAR_ISSUE_ID:-msgvault-sync}"
QUIET="false"
VERBOSE="false"

print_help() {
  cat <<HELP
Usage:
  ${SCRIPT_NAME} [options]

Description:
  Run msgvault sync for scheduled automation. The sync log is written to
  ${LOG_FILE}. Backups are handled by tools/msgvault/backup.

Options:
  --verbose  Enable verbose helper diagnostics through DNB_VERBOSE=1.
  --quiet    Disable helper diagnostics, even when DNB_VERBOSE=1.
  --help     Show this help.

Environment:
  DNB_POLYBAR_ISSUES_FILE          Polybar issues file.
  DNB_MSGVAULT_POLYBAR_ISSUE_ID    Polybar issue id.
HELP
}

parse_arguments() {
  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
    --verbose)
      VERBOSE="true"
      export DNB_VERBOSE="1"
      shift
      ;;
    --quiet)
      QUIET="true"
      shift
      ;;
    --help)
      print_help
      exit 0
      ;;
    --*)
      echo "ERROR: unknown option: ${1}" >&2
      print_help >&2
      exit 1
      ;;
    *)
      echo "ERROR: positional arguments are not supported: ${1}" >&2
      print_help >&2
      exit 1
      ;;
    esac
  done

  if [[ "${QUIET}" == "true" ]]; then
    VERBOSE="false"
    unset DNB_VERBOSE
  elif [[ "${DNB_VERBOSE:-}" == "1" ]]; then
    VERBOSE="true"
  fi
}

parse_arguments "$@"
mkdir -p "${LOG_BASE_DIR}"

# dnb_msgvault_log
#
# Append one message to the cronjob log file.
#
# Parameters:
#   $1 - Message to append.
#
# Behaviour:
#   Writes the message as-is into LOG_FILE.
#
# Example:
#   dnb_msgvault_log "Run started: $(date --iso-8601=seconds)"
dnb_msgvault_log() {
  local message="${1:-}"

  echo "${message}" >>"${LOG_FILE}"
}

dnb_msgvault_abort() {
  local exit_code="${1:-143}"

  dnb_msgvault_log "Run interrupted: $(date --iso-8601=seconds)"
  exit "${exit_code}"
}

# dnb_msgvault_report_failure
#
# Add a Polybar issue for a msgvault cronjob failure.
#
# Parameters:
#   $1 - Failure reason.
#
# Behaviour:
#   Calls dnb_msgvault_add_polybar_issue if the helper function is available.
#   Logs a warning when the issue cannot be written.
#
# Example:
#   dnb_msgvault_report_failure "msgvault sync failed"
dnb_msgvault_report_failure() {
  local failure_reason="${1:-unknown msgvault failure}"

  if ! declare -F dnb_msgvault_add_polybar_issue >/dev/null 2>&1; then
    dnb_msgvault_log "WARN: dnb_msgvault_add_polybar_issue is not available"
    return 0
  fi

  if ! dnb_msgvault_add_polybar_issue \
    --reason "${failure_reason}" \
    --log-file "${LOG_FILE}" \
    --issue-id "${POLYBAR_ISSUE_ID}" \
    --issues-file "${POLYBAR_ISSUES_FILE}"; then
    dnb_msgvault_log "WARN: failed to add polybar issue for msgvault failure"
  fi
}

trap 'dnb_msgvault_abort 129' HUP
trap 'dnb_msgvault_abort 130' INT
trap 'dnb_msgvault_abort 143' TERM

if [[ ! -x "${MSGVAULT_BIN}" ]]; then
  failure_reason="msgvault binary not found or not executable: ${MSGVAULT_BIN}"

  {
    echo "============================================================"
    echo "Run started: $(date --iso-8601=seconds)"
    echo "ERROR: ${failure_reason}"
    echo "Run finished: $(date --iso-8601=seconds)"
    echo "============================================================"
    echo
  } >>"${LOG_FILE}"

  dnb_msgvault_report_failure "${failure_reason}"
  exit 1
fi

{
  echo "============================================================"
  echo "Run started: $(date --iso-8601=seconds)"
  echo "Command: ${MSGVAULT_BIN} sync"
  echo "------------------------------------------------------------"
} >>"${LOG_FILE}"

"${MSGVAULT_BIN}" sync --verbose >>"${LOG_FILE}" 2>&1
sync_exit_code="$?"

if [[ "${sync_exit_code}" -ne 0 ]]; then
  failure_reason="msgvault sync failed with exit code ${sync_exit_code}"

  {
    echo "------------------------------------------------------------"
    echo "ERROR: ${failure_reason}"
    echo "Run finished: $(date --iso-8601=seconds)"
    echo "============================================================"
    echo
  } >>"${LOG_FILE}"

  dnb_msgvault_report_failure "${failure_reason}"
  exit "${sync_exit_code}"
fi

{
  echo "------------------------------------------------------------"
  echo "Run finished: $(date --iso-8601=seconds)"
  echo "============================================================"
  echo
} >>"${LOG_FILE}"
