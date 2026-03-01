#!/bin/bash

set -uo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin"

# ------------------------------------------------------------
# msgvault cron wrapper
# Creates a timestamped log file in ~/.logs/msgvault/
# ------------------------------------------------------------

LOG_BASE_DIR="${HOME}/.logs/msgvault"
LOG_FILE="${LOG_BASE_DIR}/setup-log-$(date +%Y%m%d-%H%M%S).log"
MSGVAULT_BIN="${HOME}/.local/bin/msgvault"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_PATH="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ISSUES_ADD_SCRIPT="${DOTFILES_PATH}/configs/system/polybar/scripts/issues-add.sh"
ISSUE_ID="msgvault-sync"

mkdir -p "${LOG_BASE_DIR}"

add_polybar_issue() {
  local failure_reason="$1"

  if [[ ! -x "${ISSUES_ADD_SCRIPT}" ]]; then
    {
      echo "WARN: polybar issue script not executable: ${ISSUES_ADD_SCRIPT}"
      echo "WARN: original failure: ${failure_reason}"
    } >>"${LOG_FILE}"
    return
  fi

  "${ISSUES_ADD_SCRIPT}" \
    --id "${ISSUE_ID}" \
    --prio 1 \
    --label "msgvault sync failed" \
    --description "${failure_reason}. Log: ${LOG_FILE}" >>"${LOG_FILE}" 2>&1 || {
    echo "WARN: failed to add polybar issue for msgvault sync failure" >>"${LOG_FILE}"
  }
}

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

  add_polybar_issue "${failure_reason}"
  exit 1
fi

{
  echo "============================================================"
  echo "Run started: $(date --iso-8601=seconds)"
  echo "Command: ${MSGVAULT_BIN} sync"
  echo "------------------------------------------------------------"
} >>"${LOG_FILE}"

"${MSGVAULT_BIN}" sync >>"${LOG_FILE}" 2>&1
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

  add_polybar_issue "${failure_reason}"
  exit "${sync_exit_code}"
fi

{
  echo "------------------------------------------------------------"
  echo "Run finished: $(date --iso-8601=seconds)"
  echo "============================================================"
  echo
} >>"${LOG_FILE}"
