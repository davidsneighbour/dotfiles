#!/bin/bash
# executed by the command interpreter for interactive non-login shells

# set to 0 or 1 to regulate verbosity
export DNB_VERBOSE=0

if [[ ${DNB_VERBOSE:-0} -gt 1 ]]; then
  LOG_FILE="${HOME}/.logs/bashrc-$(date +'%Y%m%d-%H%M%S').log"
  exec > >(tee >(sed -r 's/\x1B\[[0-9;]*[mK]//g' >>"${LOG_FILE}")) 2>&1
fi

DOTFILES_PATH="${HOME}/github.com/davidsneighbour/dotfiles"

# load the bash configuration
# shellcheck disable=SC1091
source "${DOTFILES_PATH}"/bashrc/bashrc
. "/home/patrick/.deno/env"
source /home/patrick/.local/share/bash-completion/completions/deno.bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


export GPG_TTY="$(tty)"
gpg-connect-agent updatestartuptty /bye >/dev/null
