#!/bin/bash

# battery meter for bluetooth devices
busctl --user call org.gnome.Shell.Extensions /org/gnome/Shell/Extensions org.gnome.Shell.Extensions InstallRemoteExtension s Bluetooth-Battery-Meter@maniacx.github.com
