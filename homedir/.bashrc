#!/bin/bash

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

for FILE in "${DOTFILES_PATH}"/homedir/bash/{eval,options,bash,functions,exports,aliases,completion,prompt}; do
  # this routine ranges through a folder of filenames that we don't explicitly know (@davidsneighbour)
  # shellcheck source=/dev/null
  [ -r "${FILE}" ] && source "${FILE}"
done
unset FILE

# shellcheck source=homedir/.cargo/env
source "${HOME}/.cargo/env"
