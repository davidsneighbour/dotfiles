#!/bin/bash

set -euo pipefail

log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Command failed: ${BASH_COMMAND}" >> "${LOGFILE}"
}
trap log_error ERR

DEFAULT_REPO="davidsneighbour/dotfiles"
DEFAULT_PATH="${HOME}/github.com/${DEFAULT_REPO}"
LOGFILE="$(pwd)/log-error-$(date +%Y%m%d-%H%M%S).log"

REPO="${1:-${DEFAULT_REPO}}"
TARGET_PATH="${2:-${DEFAULT_PATH}}"

echo "Cloning repository '${REPO}' into '${TARGET_PATH}'..."
mkdir -p "${TARGET_PATH}"

cd "${TARGET_PATH}"

if [ -z "$(ls -A "${TARGET_PATH}")" ]; then
  git init -b main
  git remote add origin "https://github.com/${REPO}"
fi

# verify that it's the proper repository
if ! git remote get-url origin | grep -q "${REPO}"; then
  echo "Error: Directory '${TARGET_PATH}' does not match '${REPO}'." >&2
  log_error
  exit 1
fi

# Fetch latest changes
git pull origin main
git submodule update --init --recursive

echo "Repository cloned successfully."

# Run install script if present
if [ -x "./install.sh" ]; then
  ./install.sh
else
  echo "Warning: No executable 'install.sh' found in '${TARGET_PATH}'." >&2
fi
