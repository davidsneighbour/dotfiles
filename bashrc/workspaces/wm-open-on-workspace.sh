#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF_USAGE
Usage:
  ${SCRIPT_NAME} --workspace <N> --command <cmd> [--verbose]
  ${SCRIPT_NAME} --help

Open a program on a target workspace and switch to that workspace first.

Options:
  --workspace <N>   Workspace number (1-based).
  --command <cmd>   Command to execute (passed to: bash -lc "<cmd>").
  --verbose         Print debug information to stderr.
  --help            Show this help.

Examples:
  ${SCRIPT_NAME} --workspace 3 --command "code"
  ${SCRIPT_NAME} --workspace 2 --command "google-chrome --new-window"
EOF_USAGE
}

die() {
  local message="$1"
  echo "ERROR: ${message}" >&2
  echo >&2
  usage >&2
  exit 1
}

logv() {
  local message="$1"
  if [[ "${VERBOSE}" == "1" ]]; then
    echo "DEBUG: ${message}" >&2
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

switch_to_workspace_wmctrl() {
  local target_idx="$1"
  wmctrl -s "${target_idx}"
}

switch_to_workspace_xdotool() {
  local target_idx="$1"
  xdotool set_desktop "${target_idx}"
}

get_total_workspaces_wmctrl() {
  wmctrl -d | wc -l | tr -d ' '
}

get_total_workspaces_xdotool() {
  xdotool get_num_desktops
}

VERBOSE="0"
WORKSPACE_NUM=""
COMMAND=""

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
  --workspace)
    shift
    [[ $# -gt 0 ]] || die "--workspace requires a value"
    WORKSPACE_NUM="$1"
    shift
    ;;
  --command)
    shift
    [[ $# -gt 0 ]] || die "--command requires a value"
    COMMAND="$1"
    shift
    ;;
  *)
    die "Unknown option: $1"
    ;;
  esac
done

[[ -n "${WORKSPACE_NUM}" ]] || die "--workspace is required"
[[ -n "${COMMAND}" ]] || die "--command is required"
[[ "${WORKSPACE_NUM}" =~ ^[0-9]+$ ]] || die "--workspace must be a positive integer (1-based), got: ${WORKSPACE_NUM}"
[[ "${WORKSPACE_NUM}" -ge 1 ]] || die "--workspace must be >= 1, got: ${WORKSPACE_NUM}"

BACKEND=""
if need_cmd wmctrl; then
  BACKEND="wmctrl"
elif need_cmd xdotool; then
  BACKEND="xdotool"
else
  die "Neither wmctrl nor xdotool is installed. Install one: sudo apt install wmctrl (recommended) or sudo apt install xdotool"
fi

logv "Backend: ${BACKEND}"

TOTAL=""
if [[ "${BACKEND}" == "wmctrl" ]]; then
  TOTAL="$(get_total_workspaces_wmctrl)"
else
  TOTAL="$(get_total_workspaces_xdotool)"
fi

[[ "${TOTAL}" =~ ^[0-9]+$ ]] || die "Could not determine total workspace count"
[[ "${TOTAL}" -ge 1 ]] || die "Workspace count seems invalid: ${TOTAL}"

if [[ "${WORKSPACE_NUM}" -gt "${TOTAL}" ]]; then
  die "--workspace ${WORKSPACE_NUM} exceeds available workspaces (${TOTAL})"
fi

TARGET_IDX=$((WORKSPACE_NUM - 1))
logv "Switching to workspace index: ${TARGET_IDX}"

if [[ "${BACKEND}" == "wmctrl" ]]; then
  switch_to_workspace_wmctrl "${TARGET_IDX}"
else
  switch_to_workspace_xdotool "${TARGET_IDX}"
fi

logv "Launching command: ${COMMAND}"
nohup bash -lc "${COMMAND}" >/dev/null 2>&1 &

logv "Done"
