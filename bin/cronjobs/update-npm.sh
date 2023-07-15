#!/bin/bash

echo "starting update-npm.sh"

# exit if any command fails
set -e

source /home/patrick/.bashrc


# Load nvm
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 20.3.0

# now node works
node -e "console.log('hello')"
node --version

# npm works too!
npm --version

# update global npm packages
/home/patrick/.nvm/versions/node/v20.3.0/bin/npm -g install svgo cypress fixpack jshint \
    lerna-wizard lerna lighthouse netlify-cli \
    npm-check-updates svgo typescript \
    @davidsneighbour/remark-config \
    @socketsecurity/cli

echo "done with update-npm.sh"
