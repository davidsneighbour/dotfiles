#!/bin/bash
# executed by the command interpreter for non-interactive login shells

# shell environment variables
DNB_IS_INTERACTIVE=0
DOTFILES_PATH="${HOME}/.dotfiles"
BASHRC_PATH="${DOTFILES_PATH}/bashrc"
LOG_PATH="bash/profile"

# set to 0 or 1 to regulate verbosity
export DNB_VERBOSE=1

# load the library functions
for FILE in "${BASHRC_PATH}"/lib/*/*.bash; do
  # shellcheck disable=SC1090
  [[ -f "${FILE}" && -r "${FILE}" ]] && source "${FILE}"
done

# set log file for .bashrc runs
if [[ ${DNB_VERBOSE:-0} -gt 1 ]]; then
  LOG_FILE="${HOME}/.logs/${LOG_PATH}/$(date +'%Y%m%d-%H%M%S').log"
  exec > >(tee >(sed -r 's/\x1B\[[0-9;]*[mK]//g' >>"${LOG_FILE}")) 2>&1
fi

# load the bash configuration
# shellcheck disable=SC1091
if [[ "${DNB_IS_INTERACTIVE}" == "1" ]]; then
  source "${BASHRC_PATH}"/bashrc
fi

# load the bash programs configuration
for FILE in "${BASHRC_PATH}"/partials/_programs/*; do
  # shellcheck disable=SC1090
  [[ -f "${FILE}" && -r "${FILE}" ]] && source "${FILE}"
done

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
