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
fi

DOTBOT_DIR="dotbot"
DOTBOT_BIN="bin/dotbot"
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${BASEDIR}"
git -C "${DOTBOT_DIR}" submodule sync --quiet --recursive
git submodule update --init --recursive "${DOTBOT_DIR}"

"${BASEDIR}/${DOTBOT_DIR}/${DOTBOT_BIN}" \
  --base-directory "${BASEDIR}" \
  --config-file "${DOTBOT_CONFIG}" \
  --force-color \
  --exit-on-failure \
  -vv
