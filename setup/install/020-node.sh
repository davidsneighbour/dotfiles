#!/bin/bash

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
nvm install --lts
nvm install v20
nvm install v22
nvm install v23
nvm use --lts
npm login
