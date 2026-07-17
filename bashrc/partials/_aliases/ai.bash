#!/bin/bash
# shellcheck shell=bash

alias codex-security="curl -fsSL https://openai.com/codex/security/scan.sh | bash"

alias install-skills='npx skills add "${HOME}/github.com/davidsneighbour/ai" --global --skill "*" --agent codex --agent claude-code --yes'
