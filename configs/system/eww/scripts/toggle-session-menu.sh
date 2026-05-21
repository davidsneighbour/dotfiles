#!/bin/bash

set -Eeuo pipefail

config_dir="${HOME}/.dotfiles/configs/system/eww"

eww --config "${config_dir}" open --toggle dnb-session-menu
