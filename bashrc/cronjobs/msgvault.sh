#!/bin/bash

set -uo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin"

LOG_BASE_DIR="${HOME}/.logs/msgvault"
LOG_FILE="${LOG_BASE_DIR}/$(date +%Y%m%d).log"
LOCK_FILE="${LOG_BASE_DIR}/msgvault.lock"
MSGVAULT_BIN="${HOME}/.local/bin/msgvault"
MSGVAULT_DIR="${DNB_MSGVAULT_DIR:-${HOME}/.msgvault}"
MSGVAULT_BACKUP_DIR="${DNB_MSGVAULT_BACKUP_DIR:-/mnt/storage/Backup/msgvault}"
MSGVAULT_BACKUP_INTERVAL_HOURS="${DNB_MSGVAULT_BACKUP_INTERVAL_HOURS:-6}"
MSGVAULT_BACKUP_LAST_SUCCESS_FILE="${MSGVAULT_BACKUP_DIR}/last-successful-backup.txt"
MSGVAULT_BACKUP_LOG_FILE="${MSGVAULT_BACKUP_DIR}/backup.log"
MSGVAULT_BACKUP_LOCK_FILE="${MSGVAULT_BACKUP_DIR}/backup.lock"
POLYBAR_ISSUES_FILE="${DNB_POLYBAR_ISSUES_FILE:-${HOME}/.config/polybar/issues.toml}"
POLYBAR_ISSUE_ID="${DNB_MSGVAULT_POLYBAR_ISSUE_ID:-msgvault-sync}"

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
dnb_msgvault_create_lock() {
  local started_at
  local host_name

  started_at="$(date --iso-8601=seconds)"
  host_name="$(hostname 2>/dev/null || echo "unknown")"

  if ! (
    set -o noclobber
    {
      echo "started_at=${started_at}"
      echo "pid=$$"
      echo "host=${host_name}"
      echo "log_file=${LOG_FILE}"
    } >"${LOCK_FILE}"
  ) 2>/dev/null; then
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
  fi

  return 0
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
# Run a msgvault backup when the configured interval is due.
#
# Parameters:
#   None.
#
# Behaviour:
#   Checks the last successful backup marker and runs dnb_msgvault_run_backup
#   when enough time has passed. Returns 0 when no backup is due or when backup
#   succeeds. Returns non-zero on interval validation or backup failure.
#
# Example:
#   dnb_msgvault_maybe_run_backup
dnb_msgvault_maybe_run_backup() {
  local backup_due_exit_code

  dnb_msgvault_backup_is_due
  backup_due_exit_code="$?"

  if [[ "${backup_due_exit_code}" -eq 1 ]]; then
    dnb_msgvault_log "Backup skipped: interval has not elapsed"
    return 0
  fi

  if [[ "${backup_due_exit_code}" -ne 0 ]]; then
    dnb_msgvault_log "ERROR: could not determine backup interval"
    return "${backup_due_exit_code}"
  fi

  dnb_msgvault_log "Backup due: running msgvault backup"
  dnb_msgvault_run_backup
}

if ! dnb_msgvault_create_lock; then
  exit 0
fi

trap dnb_msgvault_cleanup_lock EXIT

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

if ! dnb_msgvault_maybe_run_backup; then
  backup_exit_code="$?"
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
