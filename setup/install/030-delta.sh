#!/bin/bash

wget -o install.deb https://github.com/dandavison/delta/releases/download/0.18.2/git-delta-musl_0.18.2_amd64.deb
sudo dpkg -i install.deb
rm install.deb
