#!/bin/bash

set -euo pipefail

# Configuration
DEFAULT_REPO="davidsneighbour/dotfiles"
DEFAULT_PATH="${HOME}/github.com/${DEFAULT_REPO}"
LOGFILE="$(pwd)/setup-log-$(date +%Y%m%d-%H%M%S).log"

REPO="${1:-${DEFAULT_REPO}}"
TARGET_PATH="${2:-${DEFAULT_PATH}}"

# Error logging function
log_error() {
  local exit_code=$?
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Command failed: ${BASH_COMMAND}" >> "${LOGFILE}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Exit Code: ${exit_code}" >> "${LOGFILE}"
}
trap log_error ERR

# Redirect all output to the log file **while keeping it visible in the terminal**
exec > >(tee -a "${LOGFILE}") 2>&1

echo "Cloning repository '${REPO}' into '${TARGET_PATH}'..."
mkdir -p "${TARGET_PATH}"

cd "${TARGET_PATH}"

if [ -z "$(ls -A "${TARGET_PATH}")" ]; then
  git init -b main
  git remote add origin "https://github.com/${REPO}"
fi

# Verify that it's the correct repository
if ! git remote get-url origin | grep -q "${REPO}"; then
  echo "Error: Directory '${TARGET_PATH}' does not match '${REPO}'." >&2
  exit 1
fi

# Fetch latest changes
git pull origin main

# =============================
# RESET SUBMODULES IF NEEDED
# =============================
if [ -d ".git/modules" ]; then
  echo -e "\n⚠️  Warning: Existing submodules detected."
  echo "If you reset them now, all local changes will be lost."
  echo -e "If you exit now, you can re-run this script later when you're ready.\n"

  read -rp "Do you want to reset all submodules now? (y/N): " confirm
  if [[ "${confirm}" =~ ^[yY]$ ]]; then
    echo "Resetting all submodules..."

    # Step 1: Deinitialize all submodules (removes cached versions)
    git submodule deinit -f --all

    # Step 2: Remove submodule directories (cleans working directory)
    rm -rf .git/modules
    git rm -f .gitmodules

    # Step 3: Reinitialize submodules
    git submodule update --init --recursive

    echo "All submodules have been reset."
  else
    echo "Skipping submodule reset. Re-run this script later when you're ready."
    exit 0
  fi
fi

# Finalize submodule update
echo "Updating submodules..."
if ! git submodule update --init --recursive; then
  echo "⚠️  Error: A submodule reference is missing upstream."
  echo "Attempting to reset submodules to the latest 'main' branch..."

  git submodule foreach --recursive 'git fetch origin && git checkout origin/main || git checkout main'

  if ! git submodule update --init --recursive; then
    echo "❌ Failed to recover submodules. Please check manually."
    exit 1
  fi
  echo "✅ Submodules successfully reset to latest main branch."
fi

echo "Repository cloned successfully."

# Run install script if present
if [ -x "./install.sh" ]; then
  ./install.sh
else
  echo "Warning: No executable 'install.sh' found in '${TARGET_PATH}'." >&2
fi
