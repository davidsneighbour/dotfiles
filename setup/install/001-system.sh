#!/bin/bash

sudo apt update
sudo apt remove --purge totem libreoffice sssd vlc -y
sudo apt install apt-transport-https arp-scan barrier bsdmainutils \
  build-essential ca-certificates chrome-gnome-shell curl dconf-cli flameshot \
  gimp git gnome-shell-extension-manager gnome-terminal gnome-tweaks gnupg2 \
  gparted gpg grc inkscape libavcodec-dev libavcodec-extra \
  libayatana-appindicator3-dev libfuse2 libnss3-tools net-tools pdftk plocate \
  polybar python-is-python3 python3 python3-gpg python3-pip python3-virtualenv \
  qt5ct rename shutter shc smartctl software-properties-common rofi \
  texlive-extra-utils testdisk ubuntu-restricted-extras vim wget zoxide -y
sudo apt upgrade -y
sudo apt autoremove -y
sudo apt autoclean -y

mkdir -p ~/github.com/davidsneighbour ~/gitlab.com/davidsneighbour
mkdir -p ~/.config
