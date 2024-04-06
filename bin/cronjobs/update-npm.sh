#!/bin/bash
# see https://kollitsch.dev/blog/2023/update-npm-packages-in-all-available-nvm-environments/

echo "##########################################################################"
echo "starting update-npm.sh"
# shellcheck disable=SC2005
echo "$(date)"
echo "##########################################################################"

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# exit if any command fails
set -e

# Load nvm
NVM_DIR=""
if [ -z "${XDG_CONFIG_HOME-}" ]; then
  NVM_DIR="${HOME}/.nvm"
else
  NVM_DIR="${XDG_CONFIG_HOME}/nvm"
fi

export NVM_DIR
# shellcheck source=/dev/null
[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"

for DIRNAME in /home/patrick/.nvm/versions/node/*/; do

  DIR=$(basename "${DIRNAME}")
  nvm use "${DIR}"

  #   if [[ $DIR == 'references' ]]; then
  #     continue
  #   fi

  # update global npm packages
  # `npm ls -g` to list globally installed packages
nvm install --reinstall-packages-from=default --latest-npm 'lts/*'

done

echo "##########################################################################"
echo "done with update-npm.sh"
# shellcheck disable=SC2005
echo "$(date)"
echo "##########################################################################"

nvm use
