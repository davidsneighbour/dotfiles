#!/bin/bash

# vscode
mkdir -p ~/.vscode/extensions
git clone https://github.com/dracula/visual-studio-code.git ~/.vscode/extensions/theme-dracula
cd ~/.vscode/extensions/theme-dracula || exit
npm install
npm run build
# todo: remove plugin from profiles if existing

# vim 8.2+
mkdir -p ~/.vim/pack/themes/start
cd ~/.vim/pack/themes/start || exit
git clone https://github.com/dracula/vim.git dracula
