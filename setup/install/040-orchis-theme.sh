#!/bin/bash

mkdir -p "${HOME}"/github.com/vinceliuice/Orchis-theme
git clone git@github.com:vinceliuice/Orchis-theme.git "${HOME}"/github.com/vinceliuice/Orchis-theme
cd "${HOME}"/github.com/vinceliuice/Orchis-theme || exit
./install.sh --dest "${HOME}"/.themes --theme all --color standard --icon ubuntu --round 3 --libadwaita --tweaks compact --tweaks black

sudo flatpak override --filesystem=xdg-config/gtk-3.0 && sudo flatpak override --filesystem=xdg-config/gtk-4.0

# https://github.com/vinceliuice/Orchis-theme
# https://imgur.com/a/rftRZZB
# https://github.com/PapirusDevelopmentTeam/papirus-icon-theme
