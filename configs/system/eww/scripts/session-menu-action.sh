#!/bin/bash

set -Eeuo pipefail

usage() {
  local command_name
  command_name="$(basename "$0")"
  cat <<EOF
Usage: ${command_name} --action ACTION [--verbose] [--help]

Run one session action from the Eww companion session menu.

Options:
  --action ACTION  One of: logout, restart, stop.
  --verbose        Print detailed output.
  --help           Show this help message.
EOF
}

action=""
verbose=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --action" >&2
        usage >&2
        exit 1
      fi
      action="$2"
      shift 2
      ;;
    --verbose)
      verbose=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${action}" ]]; then
  echo "Missing required option: --action" >&2
  usage >&2
  exit 1
fi

if [[ "${verbose}" -eq 1 ]]; then
  echo "Running session action: ${action}"
fi

case "${action}" in
  logout)
    xfce4-session-logout --logout --fast
    ;;
  restart)
    systemctl reboot
    ;;
  stop)
    systemctl poweroff
    ;;
  *)
    echo "Unsupported action: ${action}" >&2
    usage >&2
    exit 1
    ;;
esac
