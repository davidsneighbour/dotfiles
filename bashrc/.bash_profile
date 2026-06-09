#!/bin/bash
# shellcheck shell=bash

if [[ -f "${HOME}/.profile" ]]; then
  # shellcheck disable=SC1091  # ignore, this is checked for existence before sourcing
  source "${HOME}/.profile"
fi

if [[ -f "${HOME}/.bashrc" ]]; then
  # shellcheck disable=SC1091  # ignore, this is checked for existence before sourcing
  source "${HOME}/.bashrc"
fi


# Added by Antigravity CLI installer
export PATH="/home/patrick/.local/bin:$PATH"
