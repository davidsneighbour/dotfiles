#!/bin/bash
# shellcheck disable=SC2034

set -euo pipefail

show_help() {
  local command_name
  command_name="$(basename "$0")"

  cat <<USAGE
Usage: ${command_name} [--help]

Custom backup task example.

This script is executed by the backup runner with these environment variables:
  BACKUP_NAME
  BACKUP_HOST
  BACKUP_TIMESTAMP
  BACKUP_TASK_DIR
  BACKUP_OUTPUT_DIR
  BACKUP_WORK_DIR
  BACKUP_ARCHIVE_PATH
  BACKUP_VERBOSE

Behaviour:
  * Dump files or database exports into BACKUP_WORK_DIR
  * The runner will compress BACKUP_WORK_DIR into BACKUP_ARCHIVE_PATH
  * Or create BACKUP_ARCHIVE_PATH yourself if you want full control
USAGE
}

log_info() {
  printf '[INFO] %s\n' "$1"
}

log_error() {
  printf '[ERROR] %s\n' "$1" >&2
}

main() {
  if [[ "${1:-}" == "--help" ]]; then
    show_help
    return 0
  fi

  if [[ -z "${BACKUP_WORK_DIR:-}" ]]; then
    log_error 'BACKUP_WORK_DIR is not set. Run this script through backup-runner.ts.'
    return 1
  fi

  mkdir -p "${BACKUP_WORK_DIR}"

  log_info "Creating example metadata file in ${BACKUP_WORK_DIR}"
  cat > "${BACKUP_WORK_DIR}/backup-info.txt" <<META
name=${BACKUP_NAME:-unknown}
host=${BACKUP_HOST:-unknown}
timestamp=${BACKUP_TIMESTAMP:-unknown}
source=${BACKUP_TASK_DIR:-unknown}
META

  if [[ -d "${BACKUP_TASK_DIR}/data" ]]; then
    log_info 'Copying local data directory into work directory'
    cp -a "${BACKUP_TASK_DIR}/data" "${BACKUP_WORK_DIR}/data"
  else
    log_info 'No local data directory found. Nothing else to copy.'
  fi

  log_info 'Custom backup script finished successfully'
}

main "$@"
