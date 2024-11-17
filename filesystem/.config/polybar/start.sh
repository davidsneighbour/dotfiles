#!/bin/bash

# https://github.com/TiagoDanin/Awesome-Polybar
# https://github.com/polybar/polybar/wiki/Configuration
# https://github.com/polybar/polybar-scripts
# https://github.com/adi1090x/polybar-themes/tree/master

trap 'echo "Polybar terminated unexpectedly"; exit 1' SIGTERM SIGINT

# some setup
LOGLEVEL=trace # possible values: {trace, info, notice, warning, error}
LOG_DIR="./logs"
TOP_LOGFILE="${LOG_DIR}/top.log"
BOTTOM_LOGFILE="${LOG_DIR}/bottom.log"
GENERAL_LOGFILE="${LOG_DIR}/general.log"
CONFIG_FILE="./config.ini"

mkdir -p "${LOG_DIR}"

# Redirect all script output to the general log file
exec > "${GENERAL_LOGFILE}" 2>&1

# terminate already running bar instances
killall -q polybar

# wait until the processes have been shut down
while pgrep -u "${UID}" -x polybar >/dev/null; do sleep 1; done

# log separator
echo "--- start at $(date)" | tee -a "${TOP_LOGFILE}" "${BOTTOM_LOGFILE}"

# launch new bars with nohup
nohup polybar -l="${LOGLEVEL}" -c "${CONFIG_FILE}" top 2>&1 | tee -a "${TOP_LOGFILE}" & disown
nohup polybar -l="${LOGLEVEL}" -c "${CONFIG_FILE}" bottom 2>&1 | tee -a "${BOTTOM_LOGFILE}" & disown
