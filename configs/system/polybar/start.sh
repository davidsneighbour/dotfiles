#!/bin/bash

set -Eeuo pipefail

# Polybar startup for XFCE session
# - waits for xfwm4
# - stops existing polybar instances for this user
# - writes daily logs to ~/.logs/polybar/
# - starts top and bottom bars

# shutdown xfce4 panel if it exists
# xfce4-panel --quit >/dev/null 2>&1 || true

on_err() {
  local exit_code=$?
  echo "Polybar start script failed (exit ${exit_code}) at $(date)"
  exit "${exit_code}"
}
trap on_err ERR

on_term() {
  echo "Polybar start script received termination signal at $(date)"
  exit 0
}
trap on_term SIGTERM SIGINT

# Wait for WM (xfwm4)
while ! pgrep -x xfwm4 >/dev/null 2>&1; do
  sleep 0.5
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOGLEVEL="trace" # {trace, info, notice, warning, error}
LOG_DIR="${HOME}/.logs/polybar"
DATE="$(date +%Y%m%d)"

GENERAL_LOGFILE="${LOG_DIR}/general-${DATE}.log"
TOP_LOGFILE="${LOG_DIR}/top-${DATE}.log"
BOTTOM_LOGFILE="${LOG_DIR}/bottom-${DATE}.log"

CONFIG_FILE="${SCRIPT_DIR}/config.ini"

mkdir -p "${LOG_DIR}"

# Redirect all script output to general log file (keep errors too)
exec >>"${GENERAL_LOGFILE}" 2>&1

echo "start at $(date)"
echo "script=${SCRIPT_DIR}"
echo "config=${CONFIG_FILE}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: polybar config not found: ${CONFIG_FILE}"
  exit 1
fi

# Stop existing polybar instances for this user only
if pgrep -u "${UID}" -x polybar >/dev/null 2>&1; then
  echo "stopping existing polybar instances"
  pkill -u "${UID}" -x polybar || true

  # Wait until they are fully gone
  for _ in {1..20}; do
    if ! pgrep -u "${UID}" -x polybar >/dev/null 2>&1; then
      break
    fi
    sleep 0.25
  done
fi

echo "launching bars"

# Start bars, append stdout/stderr into their own logs
polybar -l "${LOGLEVEL}" -c "${CONFIG_FILE}" top >>"${TOP_LOGFILE}" 2>&1 &
polybar -l "${LOGLEVEL}" -c "${CONFIG_FILE}" bottom >>"${BOTTOM_LOGFILE}" 2>&1 &

disown || echo "disown not available in this shell, continuing"
echo "done at $(date)"
