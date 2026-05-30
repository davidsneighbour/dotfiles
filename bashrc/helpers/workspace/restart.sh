#!/bin/bash

set -euo pipefail
xfwm4 --replace &
./configs/system/polybar/start.sh
./bashrc/helpers/theme/set-default-wallpaper.sh
