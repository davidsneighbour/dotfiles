#!/bin/bash

sudo snap remove firefox

sudo snap refresh snap-store
sudo snap refresh

sudo snap set core experimental.refresh-app-awareness=true

sudo snap install chromium
sudo snap install go --classic
sudo snap install libreoffice
sudo snap install phpstorm --classic
sudo snap install telegram-desktop
sudo snap install todoist
sudo snap install vlc
