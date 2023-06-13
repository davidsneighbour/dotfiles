#!/bin/bash

echo "starting update-npm.sh"

# exit if any command fails
set -e

# update global npm packages
npm -g install svgo cypress fixpack jshint \
    lerna-wizard lerna lighthouse netlify-cli \
    npm-check-updates svgo typescript \
    @davidsneighbour/remark-config

echo "done with update-npm.sh"
