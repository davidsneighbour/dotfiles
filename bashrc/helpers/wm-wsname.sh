#!/bin/bash

# usage: xfwm4-set-workspace-name [number name]...

_OLD_IFS=$IFS IFS=$'\n'
ws_count=$(xfconf-query -c xfwm4 -p /general/workspace_count)
ws_names=($(xfconf-query -c xfwm4 -p /general/workspace_names | tail -n+3))
IFS=$_OLD_IFS

declare -i ws_number

while [ $# -gt 0 ]; do
  ws_number=$1
  shift

  if [ $ws_number -lt 1 -o $ws_number -gt $ws_count ]; then
    echo warning: invalid workspace number 2>/dev/null
    shift
    continue
  fi

  if [ $# -eq 0 ]; then
    echo warning: no workspace name specified 2>/dev/null
    break
  fi

  ws_name=$1
  shift
  ws_names[$((ws_number - 1))]=$ws_name
done

declare -a xfconf_sets

for i in ${!ws_names[@]}; do
  xfconf_sets+=(-s "${ws_names[$i]}")
done

xfconf-query -c xfwm4 -p /general/workspace_names "${xfconf_sets[@]}"
# $ ./xfwm4-set-workspace-name 2 'ws two' 3 'workspace three'
