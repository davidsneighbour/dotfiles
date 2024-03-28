#!/bin/bash
# see https://kollitsch.dev/blog/2023/update-npm-packages-in-all-available-nvm-environments/

echo "##########################################################################"
echo "starting update-npm.sh"
# shellcheck disable=SC2005
echo "$(date)"
echo "##########################################################################"

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
  /home/patrick/.nvm/versions/node/"${DIR}"/bin/npm --no-fund --no-audit --quiet -g \
    install svgo cypress fixpack jshint \
    lerna-wizard lerna lighthouse netlify-cli npm-check-updates typescript \
    bun better-commits @davidsneighbour/remark-config @socketsecurity/cli \
    http-server npm pa11y playwright sassdoc

done

echo "##########################################################################"
echo "done with update-npm.sh"
# shellcheck disable=SC2005
echo "$(date)"
echo "##########################################################################"

nvm use
