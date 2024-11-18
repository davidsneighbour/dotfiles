#!/bin/bash

# Disable automatically mounting external hard drives
gsettings set org.gnome.desktop.media-handling automount false
gsettings set org.gnome.desktop.media-handling automount-open false

# Set the wallpaper
gsettings set org.gnome.desktop.background picture-uri "file://${HOME}/.wallpapers/wallpaper001.jpg"
gsettings set org.gnome.desktop.background picture-uri-dark "file://${HOME}/.wallpapers/wallpaper001.jpg"
