
# Backup Cinnamon keybindings and log output with timestamps

LOG_DIR="${HOME}/.logs"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
LOG_FILE="${LOG_DIR}/cron-keybindings-${TIMESTAMP}.log"
BACKUP_DIR="${HOME}/github.com/davidsneighbour/dotfiles/etc"
BACKUP_FILE="${BACKUP_DIR}/dconf-settings.conf"

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

{
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] keybindings backup start"
  /usr/bin/dconf dump /org/cinnamon/desktop/keybindings/ > "${BACKUP_FILE}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] keybindings backup done"
} >> "${LOG_FILE}" 2>&1
