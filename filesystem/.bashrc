#!/bin/bash
# executed by the command interpreter for interactive non-login shells

LOG_FILE="${HOME}/.logs/bashrc-$(date +'%Y%m%d-%H%M%S').log"
exec > >(tee \
    >(sed -r 's/\x1B\[[0-9;]*[mK]//g' >> "${LOG_FILE}") \
) 2>&1

DOTFILES_PATH="${HOME}/github.com/davidsneighbour/dotfiles"

# load the bash configuration
# shellcheck disable=SC1091
source "${DOTFILES_PATH}"/bash/bashrc
