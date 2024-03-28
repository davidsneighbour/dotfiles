#!/bin/bash

WORKINGDIR="${HOME}/.config/rofi/"
MAP="${WORKINGDIR}/workspaces.csv"

# shellcheck disable=SC2002
cat "${MAP}" |
  cut -d ',' -f 1 |
  rofi -dmenu -i -config "${WORKINGDIR}/config.rasi" -p "do" |
  head -n 1 |
  xargs -I {} --no-run-if-empty grep "{}" "${MAP}" |
  cut -d ',' -f 2 |
  head -n 1 |
  xargs -I {} --no-run-if-empty /bin/bash -c "{}"

exit 0
