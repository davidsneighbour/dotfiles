#!/bin/bash

sudo add-apt-repository ppa:libreoffice/ppa --yes --no-update
sudo add-apt-repository ppa:papirus/papirus --yes --no-update

sudo apt update
sudo apt upgrade --yes
sudo apt dist-upgrade --yes
sudo apt autoremove --yes
sudo apt clean --yes

sudo apt install -y \
    build-essential \
    curl \
    filezilla filezilla-theme-papirus filezilla-common \
    git  git-delta git-extras \
    htop \
    papirus-icon-theme papirus-folders papirus-colors \
    qbittorrent \
    software-properties-common \
    unzip \
    vlc \
    wget \
    yamllint
