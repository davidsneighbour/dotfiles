#!/bin/bash

set -euo pipefail

# ------------------------------------------------------------
# msgvault cron wrapper
# Creates daily log files in ~/.logs/mail/
# ------------------------------------------------------------

# Configuration
LOG_BASE_DIR="${HOME}/.logs/mail"
DATE="$(date +%Y%m%d)"
LOG_FILE="${LOG_BASE_DIR}/msgvault-cron-${DATE}.log"
MSGVAULT_BIN="${HOME}/.local/bin/msgvault"

# Ensure log directory exists
mkdir -p "${LOG_BASE_DIR}"

# Validate binary exists
if [[ ! -x "${MSGVAULT_BIN}" ]]; then
  echo "ERROR: msgvault binary not found or not executable: ${MSGVAULT_BIN}" >>"${LOG_FILE}"
  exit 1
fi

# Run sync
{
  echo "============================================================"
  echo "Run started: $(date --iso-8601=seconds)"
  echo "Command: ${MSGVAULT_BIN} sync"
  echo "------------------------------------------------------------"

  "${MSGVAULT_BIN}" sync

  echo "------------------------------------------------------------"
  echo "Run finished: $(date --iso-8601=seconds)"
  echo "============================================================"
  echo
} >>"${LOG_FILE}" 2>&1
