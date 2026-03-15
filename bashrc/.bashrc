#!/bin/bash
# executed by the command interpreter for interactive non-login shells

# shell environment variables
DNB_IS_INTERACTIVE=1
DNB_NAMESPACE=davidsneighbour
DOTFILES_PATH="${HOME}/.dotfiles"
LOG_PATH="bash/bashrc"
export DNB_IS_INTERACTIVE DNB_NAMESPACE DOTFILES_PATH LOG_PATH

# set to 0 or 1 to regulate verbosity
export DNB_VERBOSE=1

# load the library functions
for FILE in "${DOTFILES_PATH}"/bashrc/_lib/*; do
  # shellcheck disable=SC1090
  [ -f "${FILE}" ] && source "${FILE}"
done

# set log file for .bashrc runs
if [[ ${DNB_VERBOSE:-0} -gt 1 ]]; then
  LOG_FILE="${HOME}/.logs/${LOG_PATH}/$(date +'%Y%m%d-%H%M%S').log"
  exec > >(tee >(sed -r 's/\x1B\[[0-9;]*[mK]//g' >>"${LOG_FILE}")) 2>&1
fi

# load the bash configuration
# shellcheck disable=SC1091
if [[ "${DNB_IS_INTERACTIVE}" == "1" ]]; then
  source "${DOTFILES_PATH}"/bashrc/bashrc
fi

# load the bash programs configuration
for FILE in "${DOTFILES_PATH}"/bashrc/partials/_programs/*; do
  # shellcheck disable=SC1090
  [ -f "${FILE}" ] && source "${FILE}"
done
