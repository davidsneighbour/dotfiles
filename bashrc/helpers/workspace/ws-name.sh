#!/bin/bash

# usage: ws-name.sh [number name]...
# $ ws-name.sh 2 'ws two' 3 'workspace three'

set -euo pipefail

: "${BASHRC_PATH:?BASHRC_PATH must be set before loading Bash helper files}"
for FILE in "${BASHRC_PATH}"/lib/*/*.bash; do
  # shellcheck disable=SC1090
  [[ -f "${FILE}" && -r "${FILE}" ]] && source "${FILE}"
done

dnb_require_cmd xfconf-query

_OLD_IFS=${IFS} IFS=$'\n'
ws_names=()

ws_count=$(xfconf-query -c xfwm4 -p /general/workspace_count)
if ! mapfile -t ws_names < <(xfconf-query -c xfwm4 -p /general/workspace_names | tail -n +3); then
  echo "warning: failed to read workspace names" >&2
fi
IFS=${_OLD_IFS}

declare -i ws_number

while [ $# -gt 0 ]; do
  ws_number=$1
  shift

  if [ "${ws_number}" -lt 1 ] || [ "${ws_number}" -gt "${ws_count}" ]; then
    echo "warning: invalid workspace number" 2>/dev/null
    shift
    continue
  fi

  if [ $# -eq 0 ]; then
    echo "warning: no workspace name specified" 2>/dev/null
    break
  fi

  ws_name=$1
  shift
  ws_names[ws_number - 1]=${ws_name}
done

declare -a xfconf_sets

for i in "${!ws_names[@]}"; do
  xfconf_sets+=(-s "${ws_names[${i}]}")
done

xfconf-query -c xfwm4 -p /general/workspace_names "${xfconf_sets[@]}"
