#!/bin/bash

set -e

DOTBOT_CONFIG="etc/config.update.yaml"
if [[ $# -gt 0 ]]
then

  if [ "${1}" = "install" ]
  then
    DOTBOT_CONFIG="etc/config.install.yaml"
  fi

fi

echo "${DOTBOT_CONFIG}"

DOTBOT_DIR="dotbot"
DOTBOT_BIN="bin/dotbot"
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${BASEDIR}"
git -C "${DOTBOT_DIR}" submodule sync --quiet --recursive
git submodule update --init --recursive "${DOTBOT_DIR}"

#"${BASEDIR}/${DOTBOT_DIR}/${DOTBOT_BIN}" -d "${BASEDIR}" -c "${DOTBOT_CONFIG}" "${@}"
"${BASEDIR}/${DOTBOT_DIR}/${DOTBOT_BIN}" -d "${BASEDIR}" -c "${DOTBOT_CONFIG}"
