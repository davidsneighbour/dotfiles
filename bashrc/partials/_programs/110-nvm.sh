# shellcheck shell=bash
# load nvm (node and npm)
export NVM_DIR="${HOME}/.nvm"
[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh" # This loads nvm

if dnb_is_interactive; then
  [ -s "${NVM_DIR}/bash_completion" ] && \. "${NVM_DIR}/bash_completion"

  # Ensure default Node version has its global npm binaries/completions available
  if command -v nvm >/dev/null 2>&1; then
    nvm use --silent default >/dev/null 2>&1
  fi
fi
