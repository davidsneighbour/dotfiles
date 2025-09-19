#!/bin/bash
set -euo pipefail

# synch download directory
LOG_DIR="${HOME}/.logs/cron"
TIMESTAMP="$(date '+%Y%m%d')"
LOG_FILE="${LOG_DIR}/download-synch-${TIMESTAMP}.log"
mkdir -p "${LOG_DIR}"

{
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] download-synch backup start"

  # Only run on host 'donald'
  current_host=$(hostname -s)
  if [[ "$current_host" != "donald" ]]; then
    echo "This script runs only on host 'donald'. Current host is '$current_host'. Exiting."
    exit 0
  fi

  # Proceed with rsync only if hostname match
  rsync -rztv \
    patrick@192.168.1.201:/home/patrick/Downloads/ \
    /home/patrick/Downloads/000_unkle \
    --exclude '.incoming' \
    --delete

  rsync -rztv \
    /home/patrick/Downloads/000_synchback \
    patrick@192.168.1.201:/home/patrick/Downloads/ \
    --exclude '.incoming' \
    --delete

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] download-synch backup done"
} >> "${LOG_FILE}" 2>&1
