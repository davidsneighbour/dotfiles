#!/bin/bash
# executed by the command interpreter for interactive non-login shells

LOG_FILE="$HOME/.logs/bashrc-$(date +'%Y%m%d-%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

DOTFILES_PATH="${HOME}/github.com/davidsneighbour/dotfiles"

# load the bash configuration
source "${DOTFILES_PATH}"/bash/bashrc
