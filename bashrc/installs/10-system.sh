#!/bin/bash

sudo add-apt-repository ppa:libreoffice/ppa --yes --no-update
sudo add-apt-repository ppa:papirus/papirus --yes --no-update
sudo add-apt-repository ppa:openshot.developers/ppa --yes --no-update

sudo apt update
sudo apt upgrade --yes
sudo apt dist-upgrade --yes
sudo apt autoremove --yes
sudo apt clean --yes

sudo apt install -y \
  build-essential \
  conky-all apcupsd audacious moc mpd \
  coreutils \
  curl \
  libimage-exiftool-perl \
  feh \
  ffmpeg \
  filezilla filezilla-theme-papirus filezilla-common \
  git git-delta git-extras \
  htop \
  jsonnet \
  golang-go \
  meld \
  openshot-qt python3-openshot \
  papirus-icon-theme papirus-folders papirus-colors \
  pulseaudio-utils \
  qbittorrent \
  shfmt \
  software-properties-common \
  unzip \
  vlc \
  wget \
  wmctrl \
  yad \
  yamllint

sudo snap install vale
