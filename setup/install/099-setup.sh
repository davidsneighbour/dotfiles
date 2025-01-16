#!/bin/bash

# Disable automatically mounting external hard drives
gsettings set org.gnome.desktop.media-handling automount false
gsettings set org.gnome.desktop.media-handling automount-open false

# Set the wallpaper
gsettings set org.gnome.desktop.background picture-uri "file://${HOME}/.wallpapers/wallpaper001.jpg"
gsettings set org.gnome.desktop.background picture-uri-dark "file://${HOME}/.wallpapers/wallpaper001.jpg"

# Set temperature unit to centigrade
gsettings set org.gnome.GWeather4 temperature-unit 'centigrade'

# Set the order of apps to alphabetical
gsettings set org.gnome.shell app-picker-layout "[]"
