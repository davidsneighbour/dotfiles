#!/bin/bash

set -uo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin"

SCRIPT_NAME="$(basename "${0}")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DNB_MSGVAULT_CONFIG_FILE="${DNB_MSGVAULT_CONFIG_FILE:-${SCRIPT_DIR}/config.env}"
DNB_MSGVAULT_CONFIG_BACKUP_DIR=""

if [[ -f "${DNB_MSGVAULT_CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  if ! source "${DNB_MSGVAULT_CONFIG_FILE}"; then
    echo "ERROR: could not load msgvault config: ${DNB_MSGVAULT_CONFIG_FILE}" >&2
    exit 1
  fi
elif [[ -z "${DNB_MSGVAULT_BACKUP_DIR:-}" ]]; then
  echo "ERROR: msgvault config file not found: ${DNB_MSGVAULT_CONFIG_FILE}" >&2
  exit 1
fi

LOG_BASE_DIR="${HOME}/.logs/msgvault"
LOG_FILE="${LOG_BASE_DIR}/sync-$(date +%Y%m%d).log"
MSGVAULT_BIN="${HOME}/.local/bin/msgvault"
MSGVAULT_DIR="${DNB_MSGVAULT_DIR:-${HOME}/.msgvault}"
MSGVAULT_BACKUP_DIR="${DNB_MSGVAULT_BACKUP_DIR:-${DNB_MSGVAULT_CONFIG_BACKUP_DIR}}"

if [[ -z "${MSGVAULT_BACKUP_DIR}" ]]; then
  echo "ERROR: msgvault backup directory is not configured." >&2
  exit 1
fi

MSGVAULT_BACKUP_INTERVAL_HOURS="${DNB_MSGVAULT_BACKUP_INTERVAL_HOURS:-6}"
MSGVAULT_BACKUP_LAST_SUCCESS_FILE="${MSGVAULT_BACKUP_DIR}/last-successful-backup.txt"
MSGVAULT_BACKUP_LOG_FILE="${LOG_BASE_DIR}/backup-$(date +%Y%m%d-%H%M).log"
MSGVAULT_BACKUP_LOCK_FILE="${MSGVAULT_BACKUP_DIR}/backup.lock"
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
  DNB_MSGVAULT_DIR                 msgvault home directory.
  DNB_MSGVAULT_CONFIG_FILE         sourceable config file.
  DNB_MSGVAULT_BACKUP_DIR          override configured backup directory.
  DNB_MSGVAULT_BACKUP_INTERVAL_HOURS
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

# dnb_msgvault_backup_interval_seconds
#
# Print the configured backup interval in seconds.
#
# Parameters:
#   None.
#
# Behaviour:
#   Validates DNB_MSGVAULT_BACKUP_INTERVAL_HOURS through
#   MSGVAULT_BACKUP_INTERVAL_HOURS. The value must be a positive integer.
#   Prints the interval in seconds to stdout.
#
# Example:
#   interval_seconds="$(dnb_msgvault_backup_interval_seconds)"
dnb_msgvault_backup_interval_seconds() {
  if [[ ! "${MSGVAULT_BACKUP_INTERVAL_HOURS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: invalid backup interval in hours: ${MSGVAULT_BACKUP_INTERVAL_HOURS}" >&2
    return 1
  fi

  echo $((MSGVAULT_BACKUP_INTERVAL_HOURS * 3600))
}

# dnb_msgvault_backup_is_due
#
# Determine whether the msgvault backup should run now.
#
# Parameters:
#   None.
#
# Behaviour:
#   Returns 0 when no successful backup marker exists, or when the last
#   successful backup marker is older than the configured interval. Returns 1
#   when no backup is due.
#
# Example:
#   if dnb_msgvault_backup_is_due; then
#     dnb_msgvault_run_backup
#   fi
dnb_msgvault_backup_is_due() {
  local interval_seconds
  local now_epoch
  local last_success_epoch

  if ! interval_seconds="$(dnb_msgvault_backup_interval_seconds)"; then
    return 2
  fi

  if [[ ! -f "${MSGVAULT_BACKUP_LAST_SUCCESS_FILE}" ]]; then
    return 0
  fi

  now_epoch="$(date +%s)"
  if ! last_success_epoch="$(stat -c %Y "${MSGVAULT_BACKUP_LAST_SUCCESS_FILE}" 2>/dev/null)"; then
    return 0
  fi

  if ((now_epoch - last_success_epoch >= interval_seconds)); then
    return 0
  fi

  return 1
}

# dnb_msgvault_write_backup_lock
#
# Write the backup lock file into the backup directory.
#
# Parameters:
#   None.
#
# Behaviour:
#   Writes the backup start timestamp, PID, host, source, and target directory
#   into MSGVAULT_BACKUP_LOCK_FILE.
#
# Example:
#   dnb_msgvault_write_backup_lock
dnb_msgvault_write_backup_lock() {
  local host_name

  host_name="$(hostname 2>/dev/null || echo "unknown")"

  {
    echo "started_at=$(date --iso-8601=seconds)"
    echo "pid=$$"
    echo "host=${host_name}"
    echo "source=${MSGVAULT_DIR}"
    echo "target=${MSGVAULT_BACKUP_DIR}"
  } >"${MSGVAULT_BACKUP_LOCK_FILE}"
}

# dnb_msgvault_run_backup
#
# Back up the msgvault data directory to the configured backup directory.
#
# Parameters:
#   None.
#
# Behaviour:
#   Creates the backup directory if needed. Uses rsync to mirror the contents of
#   MSGVAULT_DIR into MSGVAULT_BACKUP_DIR. Writes backup.log and updates
#   last-successful-backup.txt after a successful backup.
#
# Example:
#   dnb_msgvault_run_backup
dnb_msgvault_run_backup() {
  local backup_started_at
  local backup_finished_at
  local backup_exit_code

  if [[ ! -d "${MSGVAULT_DIR}" ]]; then
    dnb_msgvault_log "ERROR: msgvault source directory not found: ${MSGVAULT_DIR}"
    return 1
  fi

  if ! mkdir -p "${MSGVAULT_BACKUP_DIR}"; then
    dnb_msgvault_log "ERROR: could not create msgvault backup directory: ${MSGVAULT_BACKUP_DIR}"
    return 1
  fi

  backup_started_at="$(date --iso-8601=seconds)"

  dnb_msgvault_write_backup_lock

  {
    echo "============================================================"
    echo "Backup started: ${backup_started_at}"
    echo "Source: ${MSGVAULT_DIR}"
    echo "Target: ${MSGVAULT_BACKUP_DIR}"
    echo "Command: rsync -a --delete ${MSGVAULT_DIR}/ ${MSGVAULT_BACKUP_DIR}/"
    echo "------------------------------------------------------------"
  } >>"${MSGVAULT_BACKUP_LOG_FILE}"

  rsync -a --delete "${MSGVAULT_DIR}/" "${MSGVAULT_BACKUP_DIR}/" >>"${MSGVAULT_BACKUP_LOG_FILE}" 2>&1
  backup_exit_code="$?"
  backup_finished_at="$(date --iso-8601=seconds)"

  if [[ "${backup_exit_code}" -ne 0 ]]; then
    {
      echo "------------------------------------------------------------"
      echo "ERROR: backup failed with exit code ${backup_exit_code}"
      echo "Backup finished: ${backup_finished_at}"
      echo "============================================================"
      echo
    } >>"${MSGVAULT_BACKUP_LOG_FILE}"
    rm -f "${MSGVAULT_BACKUP_LOCK_FILE}"
    return "${backup_exit_code}"
  fi

  {
    echo "last_successful_backup_at=${backup_finished_at}"
    echo "source=${MSGVAULT_DIR}"
    echo "target=${MSGVAULT_BACKUP_DIR}"
  } >"${MSGVAULT_BACKUP_LAST_SUCCESS_FILE}"

  {
    echo "------------------------------------------------------------"
    echo "Backup finished: ${backup_finished_at}"
    echo "============================================================"
    echo
  } >>"${MSGVAULT_BACKUP_LOG_FILE}"

  rm -f "${MSGVAULT_BACKUP_LOCK_FILE}"

  dnb_msgvault_log "Backup finished successfully: ${backup_finished_at}"

  return 0
}

# dnb_msgvault_maybe_run_backup
#
# Preserve the old sync cronjob call site while backups are managed by the
# dedicated msgvault/backup helper.
#
# Parameters:
#   None.
#
# Behaviour:
#   Logs that backup is handled separately and returns success so the sync
#   cronjob does not mirror config files or OAuth tokens.
#
# Example:
#   dnb_msgvault_maybe_run_backup
dnb_msgvault_maybe_run_backup() {
  if [[ "${VERBOSE}" == "true" ]]; then
    dnb_msgvault_log "Backup skipped: managed separately by tools/msgvault/backup."
  fi

  return 0
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

dnb_msgvault_maybe_run_backup
backup_exit_code="$?"

if [[ "${backup_exit_code}" -ne 0 ]]; then
  failure_reason="msgvault backup failed with exit code ${backup_exit_code}"

  {
    echo "------------------------------------------------------------"
    echo "ERROR: ${failure_reason}"
    echo "Run finished: $(date --iso-8601=seconds)"
    echo "============================================================"
    echo
  } >>"${LOG_FILE}"

  dnb_msgvault_report_failure "${failure_reason}"
  exit "${backup_exit_code}"
fi

{
  echo "------------------------------------------------------------"
  echo "Run finished: $(date --iso-8601=seconds)"
  echo "============================================================"
  echo
} >>"${LOG_FILE}"
