#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF_USAGE
Usage:
  ${SCRIPT_NAME} --side <left|right> --ratio <50|66> [--verbose]
  ${SCRIPT_NAME} --help

Tile the currently active window on the current monitor.

Options:
  --side <left|right>  Place the window on the left or right side.
  --ratio <50|66>      Width ratio in percent of monitor width (50% or 66%).
  --verbose            Print debug information to stderr.
  --help               Show this help.

Examples:
  ${SCRIPT_NAME} --side left --ratio 50
  ${SCRIPT_NAME} --side right --ratio 66 --verbose
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

get_current_desktop_idx() {
  wmctrl -d | awk '/\*/ {print $1}'
}

get_desktop_workarea() {
  local desktop_idx="$1"
  local raw
  local cleaned
  local values
  local offset

  raw="$(xprop -root _NET_WORKAREA 2>/dev/null || true)"
  [[ -n "${raw}" ]] || return 1

  cleaned="$(printf '%s\n' "${raw}" | sed -E 's/^.*= //; s/,/ /g')"
  read -r -a values <<<"${cleaned}"

  offset=$((desktop_idx * 4))
  if [[ "${#values[@]}" -lt $((offset + 4)) ]]; then
    return 1
  fi

  printf '%s %s %s %s\n' "${values[offset]}" "${values[offset + 1]}" "${values[offset + 2]}" "${values[offset + 3]}"
}

VERBOSE="0"
SIDE=""
RATIO=""

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
  --side)
    shift
    [[ $# -gt 0 ]] || die "--side requires a value"
    SIDE="$1"
    shift
    ;;
  --ratio)
    shift
    [[ $# -gt 0 ]] || die "--ratio requires a value"
    RATIO="$1"
    shift
    ;;
  *)
    die "Unknown option: $1"
    ;;
  esac
done

[[ "${SIDE}" == "left" || "${SIDE}" == "right" ]] || die "--side must be left or right"
[[ "${RATIO}" == "50" || "${RATIO}" == "66" ]] || die "--ratio must be 50 or 66"

need_cmd xdotool || die "xdotool is not installed. Install with: sudo apt install xdotool"
need_cmd xrandr || die "xrandr is not installed. Install with: sudo apt install x11-xserver-utils"
need_cmd wmctrl || die "wmctrl is not installed. Install with: sudo apt install wmctrl"
need_cmd xprop || die "xprop is not installed. Install with: sudo apt install x11-utils"

ACTIVE_WIN="$(xdotool getactivewindow 2>/dev/null || true)"
[[ -n "${ACTIVE_WIN}" ]] || die "Could not determine active window"

WINDOW_GEOMETRY="$(xdotool getwindowgeometry --shell "${ACTIVE_WIN}" 2>/dev/null || true)"
[[ -n "${WINDOW_GEOMETRY}" ]] || die "Could not determine active window geometry"

eval "${WINDOW_GEOMETRY}"

[[ -n "${X:-}" && -n "${Y:-}" && -n "${WIDTH:-}" && -n "${HEIGHT:-}" ]] || die "Incomplete active window geometry data"

CENTER_X=$((X + (WIDTH / 2)))
CENTER_Y=$((Y + (HEIGHT / 2)))

logv "Active window: ${ACTIVE_WIN}"
logv "Window center: ${CENTER_X},${CENTER_Y}"

CURRENT_MONITOR=""
while IFS= read -r line; do
  geom="$(printf '%s\n' "${line}" | awk '{print $3}')"
  [[ "${geom}" =~ ^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$ ]] || continue

  MON_W="${geom%%x*}"
  rest="${geom#*x}"
  MON_H="${rest%%+*}"
  rest="${rest#*+}"
  MON_X="${rest%%+*}"
  MON_Y="${rest#*+}"

  if [[ "${CENTER_X}" -ge "${MON_X}" && "${CENTER_X}" -lt $((MON_X + MON_W)) && "${CENTER_Y}" -ge "${MON_Y}" && "${CENTER_Y}" -lt $((MON_Y + MON_H)) ]]; then
    CURRENT_MONITOR="${MON_X} ${MON_Y} ${MON_W} ${MON_H}"
    break
  fi
done < <(xrandr --query | awk '/ connected/ {print}')

[[ -n "${CURRENT_MONITOR}" ]] || die "Could not determine current monitor from xrandr output"

MON_X="$(printf '%s\n' "${CURRENT_MONITOR}" | awk '{print $1}')"
MON_Y="$(printf '%s\n' "${CURRENT_MONITOR}" | awk '{print $2}')"
MON_W="$(printf '%s\n' "${CURRENT_MONITOR}" | awk '{print $3}')"
MON_H="$(printf '%s\n' "${CURRENT_MONITOR}" | awk '{print $4}')"

WORK_X="${MON_X}"
WORK_Y="${MON_Y}"
WORK_W="${MON_W}"
WORK_H="${MON_H}"

DESKTOP_IDX="$(get_current_desktop_idx)"
if [[ "${DESKTOP_IDX}" =~ ^[0-9]+$ ]]; then
  DESKTOP_WORKAREA="$(get_desktop_workarea "${DESKTOP_IDX}" || true)"
  if [[ -n "${DESKTOP_WORKAREA}" ]]; then
    WA_X="$(printf '%s\n' "${DESKTOP_WORKAREA}" | awk '{print $1}')"
    WA_Y="$(printf '%s\n' "${DESKTOP_WORKAREA}" | awk '{print $2}')"
    WA_W="$(printf '%s\n' "${DESKTOP_WORKAREA}" | awk '{print $3}')"
    WA_H="$(printf '%s\n' "${DESKTOP_WORKAREA}" | awk '{print $4}')"

    INT_X="${MON_X}"
    if [[ "${WA_X}" -gt "${INT_X}" ]]; then
      INT_X="${WA_X}"
    fi

    INT_Y="${MON_Y}"
    if [[ "${WA_Y}" -gt "${INT_Y}" ]]; then
      INT_Y="${WA_Y}"
    fi

    MON_RIGHT=$((MON_X + MON_W))
    WA_RIGHT=$((WA_X + WA_W))
    INT_RIGHT="${MON_RIGHT}"
    if [[ "${WA_RIGHT}" -lt "${INT_RIGHT}" ]]; then
      INT_RIGHT="${WA_RIGHT}"
    fi

    MON_BOTTOM=$((MON_Y + MON_H))
    WA_BOTTOM=$((WA_Y + WA_H))
    INT_BOTTOM="${MON_BOTTOM}"
    if [[ "${WA_BOTTOM}" -lt "${INT_BOTTOM}" ]]; then
      INT_BOTTOM="${WA_BOTTOM}"
    fi

    if [[ "${INT_RIGHT}" -gt "${INT_X}" && "${INT_BOTTOM}" -gt "${INT_Y}" ]]; then
      WORK_X="${INT_X}"
      WORK_Y="${INT_Y}"
      WORK_W=$((INT_RIGHT - INT_X))
      WORK_H=$((INT_BOTTOM - INT_Y))
      logv "Workarea detected: x=${WA_X} y=${WA_Y} w=${WA_W} h=${WA_H}"
    else
      logv "Workarea intersection is empty; falling back to monitor bounds"
    fi
  else
    logv "Could not read _NET_WORKAREA; falling back to monitor bounds"
  fi
else
  logv "Could not determine current desktop index; falling back to monitor bounds"
fi

TARGET_W=$((WORK_W * RATIO / 100))
TARGET_H="${WORK_H}"
TARGET_Y="${WORK_Y}"

if [[ "${SIDE}" == "left" ]]; then
  TARGET_X="${WORK_X}"
else
  TARGET_X=$((WORK_X + WORK_W - TARGET_W))
fi

logv "Monitor: x=${MON_X} y=${MON_Y} w=${MON_W} h=${MON_H}"
logv "Usable area: x=${WORK_X} y=${WORK_Y} w=${WORK_W} h=${WORK_H}"
logv "Target: x=${TARGET_X} y=${TARGET_Y} w=${TARGET_W} h=${TARGET_H}"

wmctrl -ir "${ACTIVE_WIN}" -b remove,maximized_vert,maximized_horz
wmctrl -ir "${ACTIVE_WIN}" -e "0,${TARGET_X},${TARGET_Y},${TARGET_W},${TARGET_H}"

logv "Done"
