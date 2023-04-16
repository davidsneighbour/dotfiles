#!/bin/bash

# set -eE -o functrace

# failure() {
#   local lineno=$1
#   local msg=$2
#   echo "Failed at $lineno: $msg"
# }
# trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

# don't do anything if not running interactively
case $- in *i*) ;; *) return ;; esac

FILE="${HOME}"/.env
if [ -f "${FILE}" ]; then
  set -a
  # shellcheck source=.env
  source "${FILE}"
  set +a
fi
unset FILE

for FILE in "${DOTFILES_PATH}"/bash/{eval,options,bash,functions,exports,aliases,completion,prompt}; do
  # this routine ranges through a folder of filenames that we don't explicitly know (@davidsneighbour)
  # shellcheck source=/dev/null
  [ -r "${FILE}" ] && source "${FILE}"
done
unset FILE

# shellcheck source=home/.cargo/env
if [ -f "${HOME}/.cargo/env" ]; then
  source "${HOME}/.cargo/env"
fi

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
