#!/bin/bash

wget -O chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
sudo dpkg -i chrome.deb
sudo apt install -f
rm chrome.deb
