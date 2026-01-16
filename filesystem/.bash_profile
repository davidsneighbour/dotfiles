#!/bin/bash
# executed by the command interpreter for non-interactive login shells

LOG_FILE="${HOME}/.logs/bashprofile-$(date +'%Y%m%d-%H%M%S').log"
exec > >(tee \
    >(sed -r 's/\x1B\[[0-9;]*[mK]//g' >> "${LOG_FILE}") \
) 2>&1

DOTFILES_PATH="${HOME}/github.com/davidsneighbour/dotfiles"

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
umask 022

# load the library functions
for FILE in "${DOTFILES_PATH}"/bashrc/_lib/*; do
  # shellcheck disable=SC1090
  [ -f "${FILE}" ] && source "${FILE}"
done

# @TODO add npm
. "/home/patrick/.deno/env"
source /home/patrick/.local/share/bash-completion/completions/deno.bash

. "$HOME/.atuin/bin/env"
