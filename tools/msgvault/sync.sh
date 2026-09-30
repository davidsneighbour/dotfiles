#!/bin/bash

set -uo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin"

SCRIPT_NAME="$(basename "${0}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES_DIR="${DNB_DOTFILES_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd -P)}"
DNB_MSGVAULT_CONFIG_FILE="${DNB_MSGVAULT_CONFIG_FILE:-${SCRIPT_DIR}/config.env}"
ISSUES_LIB="${DOTFILES_DIR}/bashrc/lib/45-workspace/dnb-issues.bash"

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
  DNB_MSGVAULT_CONFIG_FILE         Helper config (default: ${SCRIPT_DIR}/config.env).
  DNB_MSGVAULT_IGNORED_ACCOUNTS    Space-separated retired accounts whose
                                   "no OAuth token" skip line is not logged.
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

if [[ -f "${DNB_MSGVAULT_CONFIG_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${DNB_MSGVAULT_CONFIG_FILE}"
fi

if [[ -f "${ISSUES_LIB}" ]]; then
  # shellcheck source=/dev/null
  source "${ISSUES_LIB}"
fi

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

# dnb_msgvault_clear_failure
#
# Remove the msgvault Polybar issue after a successful sync, so the indicator
# stops showing red once the problem is fixed.
#
# Behaviour:
#   Calls dnb_polybar_issue_remove if the helper function is available.
#   Logs a warning when the issue cannot be removed.
#
# Example:
#   dnb_msgvault_clear_failure
dnb_msgvault_clear_failure() {
  if ! declare -F dnb_polybar_issue_remove >/dev/null 2>&1; then
    dnb_msgvault_log "WARN: dnb_polybar_issue_remove is not available"
    return 0
  fi

  if ! dnb_polybar_issue_remove \
    --id "${POLYBAR_ISSUE_ID}" \
    --file "${POLYBAR_ISSUES_FILE}" \
    --log-file "${LOG_FILE}"; then
    dnb_msgvault_log "WARN: failed to remove polybar issue for msgvault"
  fi
}

# dnb_msgvault_filter_output
#
# Copy msgvault output from stdin to stdout, without the "Skipping <account>
# (no OAuth token ..." line for accounts in DNB_MSGVAULT_IGNORED_ACCOUNTS.
# These retired accounts stay in the archive, but are not synced any more.
#
# Example:
#   msgvault sync 2>&1 | dnb_msgvault_filter_output >>"${LOG_FILE}"
dnb_msgvault_filter_output() {
  local account=""
  local -a patterns=()

  for account in ${DNB_MSGVAULT_IGNORED_ACCOUNTS:-}; do
    patterns+=(-e "Skipping ${account} (no OAuth token")
  done

  if [[ "${#patterns[@]}" -eq 0 ]]; then
    cat
    return 0
  fi

  # grep exits 1 when every line is filtered out; that is not an error here.
  grep -v -F "${patterns[@]}" || true
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

"${MSGVAULT_BIN}" sync --verbose 2>&1 | dnb_msgvault_filter_output >>"${LOG_FILE}"
sync_exit_code="${PIPESTATUS[0]}"

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

dnb_msgvault_clear_failure

{
  echo "------------------------------------------------------------"
  echo "Run finished: $(date --iso-8601=seconds)"
  echo "============================================================"
  echo
} >>"${LOG_FILE}"
