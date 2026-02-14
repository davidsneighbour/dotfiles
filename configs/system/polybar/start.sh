#!/bin/bash

# https://github.com/TiagoDanin/Awesome-Polybar
# https://github.com/polybar/polybar/wiki/Configuration
# https://github.com/polybar/polybar-scripts
# https://github.com/adi1090x/polybar-themes/tree/master

trap 'echo "Polybar terminated unexpectedly"; exit 1' SIGTERM SIGINT

# Define the script directory to make paths independent
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Configuration variables
LOGLEVEL=trace # possible values: {trace, info, notice, warning, error}
LOG_DIR="${HOME}/.logs"
DATE=$(date +%Y%m%d)
TOP_LOGFILE="${LOG_DIR}/polybar/top-${DATE}.log"
BOTTOM_LOGFILE="${LOG_DIR}/polybar/bottom-${DATE}.log"
GENERAL_LOGFILE="${LOG_DIR}/polybar/general-${DATE}.log"
CONFIG_FILE="${SCRIPT_DIR}/config.ini"

# Ensure the log directory exists
mkdir -p "${LOG_DIR}/polybar"

# Redirect all script output to the general log file
exec > "${GENERAL_LOGFILE}" 2>&1

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u "${UID}" -x polybar >/dev/null; do sleep 1; done

# Log separator
echo "--- start at $(date)" | tee -a "${TOP_LOGFILE}" "${BOTTOM_LOGFILE}"

# Launch new bars with nohup
nohup polybar -l="${LOGLEVEL}" -c "${CONFIG_FILE}" top 2>&1 | tee -a "${TOP_LOGFILE}" & disown
nohup polybar -l="${LOGLEVEL}" -c "${CONFIG_FILE}" bottom 2>&1 | tee -a "${BOTTOM_LOGFILE}" & disown
