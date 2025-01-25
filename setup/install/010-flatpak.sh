#!/bin/bash

sudo add-apt-repository ppa:flatpak/stable
sudo apt update

sudo apt install flatpak gnome-software-plugin-flatpak

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.gnome.Extensions
flatpak install flathub ca.desrt.dconf-editor
flatpak install flathub io.github.flattool.Ignition
