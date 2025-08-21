#!/bin/bash
set -euo pipefail

# backup Cinnamon based keybindings
LOG_DIR="${HOME}/.logs/cron"
TIMESTAMP="$(date '+%Y%m%d')"
LOG_FILE="${LOG_DIR}/keybindings-${TIMESTAMP}.log"
BACKUP_DIR="${HOME}/github.com/davidsneighbour/dotfiles/etc/dconf"
BACKUP_FILE="${BACKUP_DIR}/keybindings.conf"
mkdir -p "${LOG_DIR}"

{
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] keybindings backup start"
  /usr/bin/dconf dump /org/cinnamon/desktop/keybindings/ > "${BACKUP_FILE}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] keybindings backup done"
} >> "${LOG_FILE}" 2>&1
