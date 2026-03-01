#!/bin/bash

set -Eeuo pipefail

# workspace-move-window.sh
# Move the currently active window to another XFCE workspace (xfwm4),
# using wmctrl (preferred) or xdotool (fallback).
#
# Examples:
#   ./workspace-move-window.sh --next
#   ./workspace-move-window.sh --prev --follow
#   ./workspace-move-window.sh --to 3
#   ./workspace-move-window.sh --to 2 --follow --verbose

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} --next [--follow] [--verbose]
  ${SCRIPT_NAME} --prev [--follow] [--verbose]
  ${SCRIPT_NAME} --to <N> [--follow] [--verbose]
  ${SCRIPT_NAME} --help

Moves the currently active window to a workspace.

Options:
  --next         Move active window to next workspace (wraps around).
  --prev         Move active window to previous workspace (wraps around).
  --to <N>       Move active window to workspace number N (1-based).
                 Example: --to 1 moves to the first workspace.
  --follow       Also switch to the target workspace after moving the window.
  --verbose      Print debug information to stderr.
  --help         Show this help.

Notes:
  * Workspaces are 1-based for --to, but internally 0-based.
  * Requires: wmctrl (preferred) or xdotool (fallback).

EOF
}

logv() {
  local msg="$1"
  if [[ "${VERBOSE}" == "1" ]]; then
    echo "DEBUG: ${msg}" >&2
  fi
}

die() {
  local msg="$1"
  echo "ERROR: ${msg}" >&2
  echo >&2
  usage >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

get_current_desktop_wmctrl() {
  wmctrl -d | awk '/\*/ {print $1}'
}

get_total_desktops_wmctrl() {
  wmctrl -d | wc -l | tr -d ' '
}

move_active_to_desktop_wmctrl() {
  local target_idx="$1"
  wmctrl -r :ACTIVE: -t "${target_idx}"
}

switch_to_desktop_wmctrl() {
  local target_idx="$1"
  wmctrl -s "${target_idx}"
}

get_current_desktop_xdotool() {
  xdotool get_desktop
}

get_total_desktops_xdotool() {
  xdotool get_num_desktops
}

move_active_to_desktop_xdotool() {
  local target_idx="$1"
  local win_id
  win_id="$(xdotool getactivewindow)"
  xdotool set_desktop_for_window "${win_id}" "${target_idx}"
}

switch_to_desktop_xdotool() {
  local target_idx="$1"
  xdotool set_desktop "${target_idx}"
}

VERBOSE="0"
FOLLOW="0"
MODE=""
TO_NUM=""

# Print help if called without parameters (but parameters are required)
if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
  --help)
    usage
    exit 0
    ;;
  --verbose)
    VERBOSE="1"
    shift
    ;;
  --follow)
    FOLLOW="1"
    shift
    ;;
  --next)
    MODE="next"
    shift
    ;;
  --prev)
    MODE="prev"
    shift
    ;;
  --to)
    MODE="to"
    shift
    [[ $# -gt 0 ]] || die "--to requires a value"
    TO_NUM="$1"
    shift
    ;;
  *)
    die "Unknown option: $1"
    ;;
  esac
done

[[ -n "${MODE}" ]] || die "You must specify exactly one of: --next, --prev, --to <N>"

# Validate --to
if [[ "${MODE}" == "to" ]]; then
  [[ "${TO_NUM}" =~ ^[0-9]+$ ]] || die "--to must be a positive integer (1-based), got: ${TO_NUM}"
  [[ "${TO_NUM}" -ge 1 ]] || die "--to must be >= 1, got: ${TO_NUM}"
fi

# Choose backend
BACKEND=""
if need_cmd wmctrl; then
  BACKEND="wmctrl"
elif need_cmd xdotool; then
  BACKEND="xdotool"
else
  die "Neither wmctrl nor xdotool is installed. Install one: sudo apt install wmctrl (recommended) or sudo apt install xdotool"
fi

logv "Backend: ${BACKEND}"
logv "Mode: ${MODE}"
logv "Follow: ${FOLLOW}"

current_idx=""
total=""
if [[ "${BACKEND}" == "wmctrl" ]]; then
  current_idx="$(get_current_desktop_wmctrl)"
  total="$(get_total_desktops_wmctrl)"
else
  current_idx="$(get_current_desktop_xdotool)"
  total="$(get_total_desktops_xdotool)"
fi

[[ "${current_idx}" =~ ^[0-9]+$ ]] || die "Could not determine current workspace index"
[[ "${total}" =~ ^[0-9]+$ ]] || die "Could not determine total workspace count"
[[ "${total}" -ge 1 ]] || die "Workspace count seems invalid: ${total}"

logv "Current workspace index: ${current_idx}"
logv "Total workspaces: ${total}"

target_idx=""
case "${MODE}" in
next)
  target_idx=$(((current_idx + 1) % total))
  ;;
prev)
  target_idx=$(((current_idx - 1 + total) % total))
  ;;
to)
  # user input is 1-based
  if [[ "${TO_NUM}" -gt "${total}" ]]; then
    die "--to ${TO_NUM} exceeds available workspaces (${total})"
  fi
  target_idx=$((TO_NUM - 1))
  ;;
*)
  die "Internal error: unknown mode ${MODE}"
  ;;
esac

logv "Target workspace index: ${target_idx}"

# Move active window
if [[ "${BACKEND}" == "wmctrl" ]]; then
  move_active_to_desktop_wmctrl "${target_idx}"
  if [[ "${FOLLOW}" == "1" ]]; then
    switch_to_desktop_wmctrl "${target_idx}"
  fi
else
  move_active_to_desktop_xdotool "${target_idx}"
  if [[ "${FOLLOW}" == "1" ]]; then
    switch_to_desktop_xdotool "${target_idx}"
  fi
fi

logv "Done"
