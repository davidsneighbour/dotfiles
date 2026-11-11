#!/bin/bash
#
# Install the LightDM GTK greeter configuration and its background image.
# The background is the lock screen image (dotfiles.session.lockScreenImage
# in configs/dotfiles.json, resolved by ../i3/session-image.sh). It is
# always installed as login-background.jpg, the path that
# lightdm-gtk-greeter.conf names; the greeter detects the real image format
# from the file content. Run again after the configured image changes.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

background_image="$("${SCRIPT_DIR}/../i3/session-image.sh" lockscreen)"

sudo cp "${background_image}" /usr/share/backgrounds/login-background.jpg
sudo cp "${SCRIPT_DIR}/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf
