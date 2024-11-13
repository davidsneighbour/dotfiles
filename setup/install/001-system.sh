#!/bin/bash

sudo apt update
sudo apt remove --purge totem libreoffice sssd vlc -y
sudo apt install apt-transport-https arp-scan bsdmainutils build-essential \
  ca-certificates chrome-gnome-shell curl flameshot gimp git gnome-terminal \
  gnome-tweaks gnupg2 gparted grc inkscape libavcodec-dev libavcodec-extra \
  libayatana-appindicator3-dev libfuse2 libnss3-tools net-tools pdftk \
  plocate python-is-python3 python3 python3-gpg python3-pip \
  python3-virtualenv qt5ct shutter shc texlive-extra-utils \
  software-properties-common rename \
  barrier ubuntu-restricted-extras vim wget zoxide -y
sudo apt upgrade -y
sudo apt autoremove -y
sudo apt autoclean -y
