#!/bin/bash

# enables debugging
#set -x

# set -eE -o functrace

auto_source() {
  # Call with either a single directory path:
  #   auto_source "/path/to/completions"
  # Or a single file path:
  #   auto_source "/path/to/completions.sh"
  # Or multiple paths:
  #   auto_source "/path/to/one" "/path/to/two"
  # Or pass an array:
  #   auto_source "${ARRAY_OF_PATHS[@]}"
  #
  for ITEM in "$@"; do
    if [ -d "${ITEM}" ]; then
      for FILE in "${ITEM}"/*; do
        # shellcheck disable=SC1090
        [ -r "${FILE}" ] && [ -f "${FILE}" ] && source "${FILE}"
      done
    elif [ -r "${ITEM}" ] && [ -f "${ITEM}" ]; then
      # shellcheck disable=SC1090
      source "${ITEM}"
    fi
  done
}

# VSCode workaround
# shellcheck source=/dev/null
TERM_PROGRAM="${TERM_PROGRAM:-}"
# shellcheck disable=SC1090
[[ "${TERM_PROGRAM}" == "vscode" ]] && . "$(/usr/bin/code --locate-shell-integration-path bash)"

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
  # shellcheck source=/dev/null
  source "${FILE}"
  set +a
fi
unset FILE

# @todo do not make DOTFILES_PATH an .env variable
# shellcheck source=/home/patrick/github.com/dotfiles
for FILE in "${DOTFILES_PATH}"/bash/{eval,options,bash,functions,exports,aliases,completions,prompt}; do
  # this routine ranges through a folder of filenames that we don't explicitly know (@davidsneighbour)
  # shellcheck source=/dev/null
  [ -r "${FILE}" ] && source "${FILE}"
done
unset FILE

# shellcheck source=home/.cargo/env
if [ -f "${HOME}/.cargo/env" ]; then
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"
fi

export NVM_DIR="${HOME}/.nvm"
# shellcheck source=/dev/null
[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh" # This loads nvm
# shellcheck source=/dev/null
[ -s "${NVM_DIR}/bash_completion" ] && \. "${NVM_DIR}/bash_completion" # This loads nvm bash_completion

# hack to disable error messages about max listeners
export NODE_OPTIONS="--require ${DOTFILES_PATH}/bin/helpers/set_max_listeners.cjs ${NODE_OPTIONS}"

eval "$(zoxide init bash)"

[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
. "$HOME/.cargo/env"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
