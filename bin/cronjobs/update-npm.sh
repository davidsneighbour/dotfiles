#!/bin/bash

echo "##########################################################################"
echo "starting update-npm.sh"
echo "##########################################################################"

# exit if any command fails
set -e

# Load nvm
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# nvm use

for DIRNAME in /home/patrick/.nvm/versions/node/*/; do

    #   if [[ $DIR == 'references' ]]; then
    #     continue
    #   fi
    DIR=$(basename "$DIRNAME")
    nvm use $DIR
    # update global npm packages
    npm -g install svgo cypress fixpack jshint \
        lerna-wizard lerna lighthouse netlify-cli \
        npm-check-updates svgo typescript \
        @davidsneighbour/remark-config \
        @socketsecurity/cli

done

echo "##########################################################################"
echo "done with update-npm.sh"
echo "##########################################################################"

npm use
