#!/bin/bash

set -uo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin"

SCRIPT_NAME="$(basename "${0}")"
LOG_BASE_DIR="${HOME}/.logs/msgvault"
LOG_FILE="${LOG_BASE_DIR}/sync-$(date +%Y%m%d).log"
LOCK_FILE="${LOG_BASE_DIR}/msgvault.lock"
MSGVAULT_BIN="${HOME}/.local/bin/msgvault"
MSGVAULT_DIR="${DNB_MSGVAULT_DIR:-${HOME}/.msgvault}"
MSGVAULT_BACKUP_DIR="${DNB_MSGVAULT_BACKUP_DIR:-/mnt/storage/Backup/msgvault}"
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
  ${LOG_FILE}. Backups are handled by bashrc/helpers/msgvault/backup.

Options:
  --verbose  Enable verbose helper diagnostics through DNB_VERBOSE=1.
  --quiet    Disable helper diagnostics, even when DNB_VERBOSE=1.
  --help     Show this help.

Environment:
  DNB_MSGVAULT_DIR                 msgvault home directory.
  DNB_MSGVAULT_BACKUP_DIR          legacy backup directory value.
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

# dnb_msgvault_create_lock
#
# Create the script-level lock file for the current cronjob run.
#
# Parameters:
#   None.
#
# Behaviour:
#   Creates LOCK_FILE atomically using noclobber. If the file already exists,
#   the function logs the existing lock content and returns 1. The caller should
#   then exit without running sync or backup.
#
# Example:
#   if ! dnb_msgvault_create_lock; then
#     exit 0
#   fi
dnb_msgvault_lock_value() {
  local key="${1}"

  awk -F= -v key="${key}" '$1 == key { print $2; exit }' "${LOCK_FILE}" 2>/dev/null
}

dnb_msgvault_lock_is_active() {
  local lock_pid
  local lock_host
  local current_host
  local lock_cmdline

  [[ -f "${LOCK_FILE}" ]] || return 1

  lock_pid="$(dnb_msgvault_lock_value "pid")"
  lock_host="$(dnb_msgvault_lock_value "host")"
  current_host="$(hostname 2>/dev/null || echo "unknown")"

  if [[ -n "${lock_host}" && "${lock_host}" != "${current_host}" ]]; then
    return 0
  fi

  if [[ ! "${lock_pid}" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  kill -0 "${lock_pid}" 2>/dev/null || return 1

  if [[ -r "/proc/${lock_pid}/cmdline" ]]; then
    lock_cmdline="$(tr '\0' ' ' <"/proc/${lock_pid}/cmdline" 2>/dev/null || echo "")"
    case "${lock_cmdline}" in
    *msgvault/sync.sh* | *msgvault/manual-sync.sh* | *msgvault.sh* | *msgvault-manual-sync.sh*)
      return 0
      ;;
    *)
      return 1
      ;;
    esac
  fi

  return 0
}

dnb_msgvault_remove_stale_lock() {
  [[ -f "${LOCK_FILE}" ]] || return 1

  if dnb_msgvault_lock_is_active; then
    return 1
  fi

  {
    echo "============================================================"
    echo "Stale lock removed: $(date --iso-8601=seconds)"
    echo "Lock file: ${LOCK_FILE}"
    echo "Previous lock content:"
    sed 's/^/  /' "${LOCK_FILE}" 2>/dev/null || echo "  Could not read lock file."
    echo "============================================================"
    echo
  } >>"${LOG_FILE}"

  rm -f "${LOCK_FILE}"
}

dnb_msgvault_create_lock() {
  local started_at
  local host_name
  local attempt

  started_at="$(date --iso-8601=seconds)"
  host_name="$(hostname 2>/dev/null || echo "unknown")"

  for attempt in 1 2; do
    if (
      set -o noclobber
      {
        echo "started_at=${started_at}"
        echo "pid=$$"
        echo "host=${host_name}"
        echo "log_file=${LOG_FILE}"
        echo "mode=cron"
      } >"${LOCK_FILE}"
    ) 2>/dev/null; then
      return 0
    fi

    if [[ "${attempt}" -eq 1 ]] && dnb_msgvault_remove_stale_lock; then
      continue
    fi

    {
      echo "============================================================"
      echo "Run skipped: $(date --iso-8601=seconds)"
      echo "Reason: lock file exists: ${LOCK_FILE}"
      echo "Existing lock content:"
      sed 's/^/  /' "${LOCK_FILE}" 2>/dev/null || echo "  Could not read lock file."
      echo "============================================================"
      echo
    } >>"${LOG_FILE}"

    return 1
  done

  return 1
}

# dnb_msgvault_cleanup_lock
#
# Remove the script-level lock file created by this process.
#
# Parameters:
#   None.
#
# Behaviour:
#   Removes LOCK_FILE on normal exit or failure. The lock file is only removed
#   when it still belongs to the current process PID.
#
# Example:
#   trap dnb_msgvault_cleanup_lock EXIT
dnb_msgvault_cleanup_lock() {
  if [[ -f "${LOCK_FILE}" ]] && grep -qx "pid=$$" "${LOCK_FILE}" 2>/dev/null; then
    rm -f "${LOCK_FILE}"
  fi
}

dnb_msgvault_abort() {
  local exit_code="${1:-143}"

  dnb_msgvault_log "Run interrupted: $(date --iso-8601=seconds)"
  dnb_msgvault_cleanup_lock
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
    dnb_msgvault_log "Backup skipped: managed separately by bashrc/helpers/msgvault/backup."
  fi

  return 0
}

if ! dnb_msgvault_create_lock; then
  exit 0
fi

trap dnb_msgvault_cleanup_lock EXIT
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
  echo "Lock file: ${LOCK_FILE}"
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
