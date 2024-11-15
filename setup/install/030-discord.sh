#!/bin/bash

wget -O discord.deb "https://discord.com/api/download?platform=linux&format=deb"
sudo dpkg -i discord.deb
sudo apt install -f
rm discord.deb

wget -O better-discord.AppImage \
  "https://github.com/BetterDiscord/Installer/releases/latest/download/BetterDiscord-Linux.AppImage"
chmod +x better-discord.AppImage
./better-discord.AppImage
rm better-discord.AppImage
