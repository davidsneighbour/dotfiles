#!/bin/bash

. "${HOME}/.atuin/bin/env"

if dnb_is_interactive; then
  [[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
  eval "$(atuin init bash)"
fi
