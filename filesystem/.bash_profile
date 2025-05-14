#!/bin/bash
# executed by the command interpreter for non-interactive login shells

LOG_FILE="$HOME/.logs/bashprofile-$(date +'%Y%m%d-%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

DOTFILES_PATH="$HOME/github.com/davidsneighbour/dotfiles"

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
umask 022

# load the library functions
for FILE in "${DOTFILES_PATH}"/bash/_lib/*; do
  [ -f "${FILE}" ] && source "${FILE}"
done

# @TODO add npm
