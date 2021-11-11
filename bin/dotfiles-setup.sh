#!/bin/bash

sudo snap install phpstorm --classic
sudo snap install inkscape
sudo snap install chromium
sudo snap install gimp
sudo snap install libreoffice

wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list

sudo apt update && sudo apt upgrade

sudo apt install openssh-server net-tools nautilus-dropbox vlc build-essential apt-transport-https sublime-text sublime-merge

sudo curl -sL https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.0/install.sh -o install_nvm.sh
sudo bash install_nvm.sh
nvm install --lts
rm install_nvm.sh
