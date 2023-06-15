#!/bin/bash

echo "starting update-npm.sh"

# exit if any command fails
set -e

# update global npm packages
/home/patrick/.nvm/versions/node/v20.3.0/bin/npm -g install svgo cypress fixpack jshint \
    lerna-wizard lerna lighthouse netlify-cli \
    npm-check-updates svgo typescript \
    @davidsneighbour/remark-config \
    @socketsecurity/cli

echo "done with update-npm.sh"
