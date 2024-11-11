#!/bin/bash

wget -O- https://download.spotify.com/debian/pubkey_224F9941A8AA6D1.gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/pubkey_224F9941A8AA6D1.gpg > /dev/null
sudo apt update
sudo apt install spotify-client
