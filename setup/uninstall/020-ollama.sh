#!/bin/bash

sudo systemctl stop ollama
sudo systemctl disable ollama
sudo rm /etc/systemd/system/ollama.service
sudo rm "$(command -v ollama)"
sudo rm -r /usr/share/ollama
sudo userdel ollama
sudo groupdel ollama
