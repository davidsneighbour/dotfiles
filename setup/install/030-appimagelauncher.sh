#!/bin/bash

wget -O appimagelauncher.deb "https://github.com/TheAssassin/AppImageLauncher/releases/download/v2.2.0/appimagelauncher_2.2.0-travis995.0f91801.bionic_amd64.deb"
sudo dpkg -i appimagelauncher.deb
sudo apt install -f
rm appimagelauncher.deb
