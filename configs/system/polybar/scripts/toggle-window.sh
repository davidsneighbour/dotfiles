#!/bin/bash
set -euo pipefail

print_help() {
  cat <<'EOF'
polybar-toggle-window

Toggle an application's window by WM_CLASS (preferred) or by title fallback.

Usage:
  polybar-toggle-window --wmclass "signal.Signal"
  polybar-toggle-window --wmclass "signal.Signal" --verbose
  polybar-toggle-window --help

Behaviour:
  * If a matching window is visible: hide it (minimise)
  * If it is hidden/minimised: show + focus it
  * If multiple windows match: uses the first match

Exit codes:
  0 success
  1 window not found
  2 invalid usage
EOF
}

WMCLASS=""
VERBOSE="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wmclass)
      WMCLASS="${2:-}"; shift 2;;
    --verbose)
      VERBOSE="1"; shift;;
    --help)
      print_help; exit 0;;
    *)
      echo "Error: Unknown option: $1" >&2
      print_help >&2
      exit 2;;
  esac
done

if [[ -z "${WMCLASS}" ]]; then
  echo "Error: --wmclass is required" >&2
  print_help >&2
  exit 2
fi

log() {
  if [[ "${VERBOSE}" == "1" ]]; then
    echo "[polybar-toggle-window] $*" >&2
  fi
}

wid="$(
  wmctrl -lx \
    | awk -v cls="${WMCLASS}" 'BEGIN{IGNORECASE=1} $3==cls {print $1; exit}'
)"

if [[ -z "${wid}" ]]; then
  echo "Error: No window found for WM_CLASS='${WMCLASS}'" >&2
  exit 1
fi

log "Using window id: ${wid}"

# Determine if minimised (Iconic) or hidden via EWMH
is_iconic="0"
if xprop -id "${wid}" WM_STATE 2>/dev/null | grep -q "Iconic"; then
  is_iconic="1"
fi

is_hidden="0"
if xprop -id "${wid}" _NET_WM_STATE 2>/dev/null | grep -q "_NET_WM_STATE_HIDDEN"; then
  is_hidden="1"
fi

log "State: iconic=${is_iconic} hidden=${is_hidden}"

if [[ "${is_iconic}" == "1" || "${is_hidden}" == "1" ]]; then
  log "Action: show/activate"
  wmctrl -ia "${wid}"
else
  log "Action: hide/minimise"
  # hidden is widely supported; if your WM ignores this, replace with:
  # wmctrl -ir "${wid}" -b add,hidden
  wmctrl -ir "${wid}" -b add,hidden
fi
