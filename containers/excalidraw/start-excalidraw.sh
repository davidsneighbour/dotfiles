#!/bin/bash

# Start script for Excalidraw web service with .env-driven config
# Designed for use with systemd or CLI launch

set -o errexit
set -o nounset
set -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="${script_dir}/excalidraw"
app_dir="${repo_dir}/excalidraw-app"

# Load .env from local or home directory
if [[ -f "${script_dir}/.env" ]]; then
  set -o allexport
  source "${script_dir}/.env"
  set +o allexport
elif [[ -f "${HOME}/.env" ]]; then
  set -o allexport
  source "${HOME}/.env"
  set +o allexport
fi

# Defaults
export PORT="${PORT:-1399}"
export NVM="${NVM:-20}"

# Use correct Node version via NVM
export NVM_DIR="${HOME}/.nvm"
# shellcheck source=/dev/null
[[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"
nvm use "${NVM}"

# 🧪 Optional check to confirm local dev setup
if [[ ! -d "${repo_dir}/node_modules" ]]; then
  echo "❌ node_modules not found. Please run 'yarn install' manually before enabling the daemon."
  exit 1
fi

# Check if vite.config.mts exists
# if [[ ! -f "${app_dir}/vite.config.mts" ]]; then
#   echo "❌ Missing vite.config.mts in ${app_dir} — exiting."
#   exit 99
# fi

# Check if vite is installed (real binary, not stub)
# if [[ ! -x "${repo_dir}/node_modules/.bin/vite" ]]; then
#   echo "📦 vite not found — running 'yarn install' in ${app_dir}..."
#   yarn --cwd "${repo_dir}" install
# fi

# Start the Vite dev server in the correct working directory
echo "🚀 Starting Vite server in ${app_dir} on port ${PORT}"
yarn --cwd "${app_dir}" vite --host --port "${PORT}" --no-open
