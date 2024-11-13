#!/bin/bash

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash
nvm install --lts
nvm install v20
nvm install v22
nvm use --lts
npm login

# quick hack because npm 10.8.0 freezes
npm install -g npm@10.3.0
