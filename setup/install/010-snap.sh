#!/bin/bash

sudo snap refresh snap-store
sudo snap set core experimental.refresh-app-awareness=true
sudo snap install chromium telegram-desktop todoist vlc
sudo snap install go --classic
sudo snap install phpstorm --classic
sudo snap refresh
