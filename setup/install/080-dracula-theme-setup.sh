#!/bin/bash

echo "Setup Dracula theme..."

# vscode
echo "Setup Dracula theme on VSCode..."
mkdir -p ~/.vscode/extensions
git clone https://github.com/dracula/visual-studio-code.git ~/.vscode/extensions/theme-dracula 2>/dev/null || true
cd ~/.vscode/extensions/theme-dracula || exit
npm install --silent
npm run build --silent
# todo: remove plugin from profiles if existing

# vim 8.2+
echo "Setup Dracula theme on Vim..."
mkdir -p ~/.vim/pack/themes/start
git clone https://github.com/dracula/vim.git ~/.vim/pack/themes/start/dracula 2>/dev/null || true
