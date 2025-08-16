#!/bin/bash

set -e

DOTBOT_CONFIG="etc/config.yaml"
if [[ $# -gt 0 ]]; then
  if [ "${1}" = "protected" ]; then
    DOTBOT_CONFIG="etc/config.protected.yaml"
  fi
  if [ "${1}" = "setup" ]; then
    DOTBOT_CONFIG="etc/config.setup.yaml"
  fi
  if [ "${1}" = "clean" ]; then
    DOTBOT_CONFIG="etc/config.clean.yaml"
  fi
  if [ "${1}" = "unkle" ]; then
    DOTBOT_CONFIG="etc/config.autostart.unkle.yaml"
  fi
  if [ "${1}" = "donald" ]; then
    DOTBOT_CONFIG="etc/config.autostart.donald.yaml"
  fi

fi

DOTBOT_DIR="modules/dotbot"
DOTBOT_BIN="bin/dotbot"
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
