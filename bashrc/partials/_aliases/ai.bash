#!/bin/bash
# shellcheck shell=bash

alias codex-security='"${HOME}/.dotfiles/bashrc/helpers/fetch-and-run.sh" --url https://openai.com/codex/security/scan.sh --interpreter bash --verbose'

alias install-skills='npx skills add "${HOME}/github.com/davidsneighbour/ai" --global --skill "*" --agent codex --agent claude-code --yes'
