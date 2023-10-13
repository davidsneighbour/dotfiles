#!/bin/bash
# see https://kollitsch.dev/blog/2023/update-npm-packages-in-all-available-nvm-environments/ for details

echo "##########################################################################"
echo "starting update-npm.sh"
echo `date`
echo "##########################################################################"

# exit if any command fails
set -e

# Load nvm
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

for DIRNAME in /home/patrick/.nvm/versions/node/*/; do

    DIR=$(basename "$DIRNAME")
    nvm use $DIR

    #   if [[ $DIR == 'references' ]]; then
    #     continue
    #   fi

    # update global npm packages
    npm --no-fund --no-audit --quiet -g install svgo cypress fixpack jshint \
        lerna-wizard lerna lighthouse netlify-cli \
        npm-check-updates svgo typescript \
        @davidsneighbour/remark-config \
        @socketsecurity/cli \
        bun

done

echo "##########################################################################"
echo "done with update-npm.sh"
echo `date`
echo "##########################################################################"

nvm use
