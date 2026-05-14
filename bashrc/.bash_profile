#!/bin/bash
# shellcheck shell=bash
# dnb-dotfiles 3003.2.0

if [[ -f "${HOME}/.profile" ]]; then
  # shellcheck disable=SC1091  # ignore, this is checked for existence before sourcing
  source "${HOME}/.profile"
fi

if [[ -f "${HOME}/.bashrc" ]]; then
  # shellcheck disable=SC1091  # ignore, this is checked for existence before sourcing
  source "${HOME}/.bashrc"
fi
