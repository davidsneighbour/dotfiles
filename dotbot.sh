#!/bin/bash

set -e

DOTBOT_CONFIG="etc/dotbot/config.yaml"
if [[ $# -gt 0 ]]; then
  CONFIG_NAME="${1}"
  ALT_CONFIG="etc/dotbot/config.${CONFIG_NAME}.yaml"
  if [[ -f "${ALT_CONFIG}" ]]; then
    DOTBOT_CONFIG="${ALT_CONFIG}"
  else
    echo "Error: Config file './${ALT_CONFIG}' not found."
    exit 1
  fi
fi

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTBOT_DIR="modules/dotbot"
DOTBOT_BIN="bin/dotbot"

cd "${BASEDIR}"
git -C "${DOTBOT_DIR}" submodule sync --quiet --recursive
git submodule update --init --recursive "${DOTBOT_DIR}"

export HOSTNAME="$(hostname)"

"${BASEDIR}/${DOTBOT_DIR}/${DOTBOT_BIN}" \
  --base-directory "${BASEDIR}" \
  --config-file "${DOTBOT_CONFIG}" \
  --force-color \
  --exit-on-failure \
  -vv
