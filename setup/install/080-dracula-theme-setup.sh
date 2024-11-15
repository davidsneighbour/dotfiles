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

# Sublime Text
echo "Setup Dracula theme on Sublime Text..."
mkdir -p ~/.config/sublime-text/Packages
git clone https://github.com/dracula/sublime.git "${HOME}/.config/sublime-text/Packages/Dracula Color Scheme" \
  2>/dev/null || true

# TODO
# https://draculatheme.com/gnome-terminal
# https://draculatheme.com/jetbrains
# https://draculatheme.com/gtk
# https://draculatheme.com/qbittorrent
# https://draculatheme.com/telegram
