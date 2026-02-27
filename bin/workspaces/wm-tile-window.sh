#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TEMPLATE_FILE="${SCRIPT_DIR}/config.toml"

usage() {
  cat <<EOF_USAGE
Usage:
  ${SCRIPT_NAME} [options]
  ${SCRIPT_NAME} --help

Tile the currently active window on the current monitor.

Options:
  --width <20-100>                 Target width in percent (default: 50).
  --height <20-100>                Target height in percent (default: 100).

  --horizontal-anchor <left|right> Horizontal anchor side (default: left).
  --horizontal-position <0-100>    Horizontal offset percentage inside available space (default: 0).

  --vertical-anchor <top|bottom>   Vertical anchor side (default: top).
  --vertical-position <0-100>      Vertical offset percentage inside available space (default: 0).

  --template <name>                Load tiling values from TOML template in ${DEFAULT_TEMPLATE_FILE}.
  --template-file <path>           Path to TOML file containing templates (default: ${DEFAULT_TEMPLATE_FILE}).
  --window-id <id>                 Tile the specified window id instead of the active window.

  --verbose                        Print debug information to stderr.
  --help                           Show this help.

Compatibility aliases (deprecated):
  --ratio <20-100>                 Alias for --width.
  --side <left|right>              Alias for --horizontal-anchor with --horizontal-position 0.

Template format:
  [tile_template."top-left-20"]
  width = 20
  height = 20
  horizontal_anchor = "left"
  horizontal_position = 0
  vertical_anchor = "top"
  vertical_position = 0

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --width 66 --height 100 --horizontal-anchor right
  ${SCRIPT_NAME} --width 40 --height 40 --horizontal-anchor left --horizontal-position 100 --vertical-anchor bottom --vertical-position 100
  ${SCRIPT_NAME} --template top-left-20
EOF_USAGE
}

die() {
  local message="$1"
  echo "ERROR: ${message}" >&2
  echo >&2
  usage >&2
  exit 1
}

warn() {
  local message="$1"
  echo "WARN: ${message}" >&2
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

require_integer_in_range() {
  local label="$1"
  local value="$2"
  local minimum="$3"
  local maximum="$4"

  [[ "${value}" =~ ^[0-9]+$ ]] || die "${label} must be an integer in range ${minimum}-${maximum}, got: ${value}"
  [[ "${value}" -ge "${minimum}" && "${value}" -le "${maximum}" ]] || die "${label} must be between ${minimum} and ${maximum}, got: ${value}"
}

apply_template() {
  local template_name="$1"
  local template_file="$2"

  [[ -f "${template_file}" ]] || die "Template TOML file not found: ${template_file}"
  need_cmd python3 || die "python3 is required to read TOML templates"

  local python_output
  python_output="$(
    python3 - "${template_file}" "${template_name}" <<'PY'
import sys

config_path = sys.argv[1]
template_name = sys.argv[2]

try:
    import tomllib
except ModuleNotFoundError:
    print("ERROR: Python 3.11+ with tomllib is required.", file=sys.stderr)
    sys.exit(2)

try:
    with open(config_path, "rb") as handle:
        data = tomllib.load(handle)
except Exception as ex:
    print(f"ERROR: Could not parse TOML file '{config_path}': {ex}", file=sys.stderr)
    sys.exit(2)

templates = data.get("tile_template")
if not isinstance(templates, dict):
    print(f"ERROR: Missing [tile_template] table in '{config_path}'.", file=sys.stderr)
    sys.exit(3)

template = templates.get(template_name)
if not isinstance(template, dict):
    print(f"ERROR: Template '{template_name}' not found under [tile_template] in '{config_path}'.", file=sys.stderr)
    sys.exit(4)

allowed = [
    "width",
    "height",
    "horizontal_anchor",
    "horizontal_position",
    "vertical_anchor",
    "vertical_position",
]

for key in allowed:
    value = template.get(key)
    if value is not None:
        print(f"{key}={value}")
PY
  )" || die "Failed to load template '${template_name}' from ${template_file}"

  while IFS='=' read -r key value; do
    case "${key}" in
    width)
      TILE_WIDTH="${value}"
      ;;
    height)
      TILE_HEIGHT="${value}"
      ;;
    horizontal_anchor)
      H_ANCHOR="${value}"
      ;;
    horizontal_position)
      H_POSITION="${value}"
      ;;
    vertical_anchor)
      V_ANCHOR="${value}"
      ;;
    vertical_position)
      V_POSITION="${value}"
      ;;
    *)
      die "Unsupported template key: ${key}"
      ;;
    esac
  done <<<"${python_output}"

  logv "Applied template '${template_name}' from ${template_file}"
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
TILE_WIDTH="50"
TILE_HEIGHT="100"
H_ANCHOR="left"
H_POSITION="0"
V_ANCHOR="top"
V_POSITION="0"
TEMPLATE_NAME=""
TEMPLATE_FILE="${DEFAULT_TEMPLATE_FILE}"
TARGET_WINDOW_ID=""

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
  --width)
    shift
    [[ $# -gt 0 ]] || die "--width requires a value"
    TILE_WIDTH="$1"
    shift
    ;;
  --height)
    shift
    [[ $# -gt 0 ]] || die "--height requires a value"
    TILE_HEIGHT="$1"
    shift
    ;;
  --horizontal-anchor)
    shift
    [[ $# -gt 0 ]] || die "--horizontal-anchor requires a value"
    H_ANCHOR="$1"
    shift
    ;;
  --horizontal-position)
    shift
    [[ $# -gt 0 ]] || die "--horizontal-position requires a value"
    H_POSITION="$1"
    shift
    ;;
  --vertical-anchor)
    shift
    [[ $# -gt 0 ]] || die "--vertical-anchor requires a value"
    V_ANCHOR="$1"
    shift
    ;;
  --vertical-position)
    shift
    [[ $# -gt 0 ]] || die "--vertical-position requires a value"
    V_POSITION="$1"
    shift
    ;;
  --template)
    shift
    [[ $# -gt 0 ]] || die "--template requires a value"
    TEMPLATE_NAME="$1"
    shift
    ;;
  --template-file)
    shift
    [[ $# -gt 0 ]] || die "--template-file requires a value"
    TEMPLATE_FILE="$1"
    shift
    ;;
  --window-id)
    shift
    [[ $# -gt 0 ]] || die "--window-id requires a value"
    TARGET_WINDOW_ID="$1"
    shift
    ;;
  --ratio)
    shift
    [[ $# -gt 0 ]] || die "--ratio requires a value"
    TILE_WIDTH="$1"
    warn "--ratio is deprecated; use --width instead"
    shift
    ;;
  --side)
    shift
    [[ $# -gt 0 ]] || die "--side requires a value"
    H_ANCHOR="$1"
    H_POSITION="0"
    warn "--side is deprecated; use --horizontal-anchor and --horizontal-position instead"
    shift
    ;;
  *)
    die "Unknown option: $1"
    ;;
  esac
done

if [[ -n "${TEMPLATE_NAME}" ]]; then
  apply_template "${TEMPLATE_NAME}" "${TEMPLATE_FILE}"
fi

require_integer_in_range "--width" "${TILE_WIDTH}" 20 100
require_integer_in_range "--height" "${TILE_HEIGHT}" 20 100
require_integer_in_range "--horizontal-position" "${H_POSITION}" 0 100
require_integer_in_range "--vertical-position" "${V_POSITION}" 0 100

[[ "${H_ANCHOR}" == "left" || "${H_ANCHOR}" == "right" ]] || die "--horizontal-anchor must be left or right"
[[ "${V_ANCHOR}" == "top" || "${V_ANCHOR}" == "bottom" ]] || die "--vertical-anchor must be top or bottom"

if [[ "${TILE_WIDTH}" -le 20 ]]; then
  warn "Requested width ${TILE_WIDTH}% is at or below 20% and may be too small to use comfortably"
fi
if [[ "${TILE_HEIGHT}" -le 20 ]]; then
  warn "Requested height ${TILE_HEIGHT}% is at or below 20% and may be too small to use comfortably"
fi

need_cmd xdotool || die "xdotool is not installed. Install with: sudo apt install xdotool"
need_cmd xrandr || die "xrandr is not installed. Install with: sudo apt install x11-xserver-utils"
need_cmd wmctrl || die "wmctrl is not installed. Install with: sudo apt install wmctrl"
need_cmd xprop || die "xprop is not installed. Install with: sudo apt install x11-utils"

if [[ -z "${TARGET_WINDOW_ID}" ]]; then
  ACTIVE_WIN="$(xdotool getactivewindow 2>/dev/null || true)"
  [[ -n "${ACTIVE_WIN}" ]] || die "Could not determine active window"
else
  ACTIVE_WIN="${TARGET_WINDOW_ID}"
fi

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

REQ_WIDTH="${TILE_WIDTH}"
REQ_HEIGHT="${TILE_HEIGHT}"

TARGET_W=$((WORK_W * REQ_WIDTH / 100))
TARGET_H=$((WORK_H * REQ_HEIGHT / 100))

X_ROOM=$((WORK_W - TARGET_W))
Y_ROOM=$((WORK_H - TARGET_H))

X_OFFSET=$((X_ROOM * H_POSITION / 100))
Y_OFFSET=$((Y_ROOM * V_POSITION / 100))

if [[ "${H_ANCHOR}" == "left" ]]; then
  TARGET_X=$((WORK_X + X_OFFSET))
else
  TARGET_X=$((WORK_X + X_ROOM - X_OFFSET))
fi

if [[ "${V_ANCHOR}" == "top" ]]; then
  TARGET_Y=$((WORK_Y + Y_OFFSET))
else
  TARGET_Y=$((WORK_Y + Y_ROOM - Y_OFFSET))
fi

logv "Monitor: x=${MON_X} y=${MON_Y} w=${MON_W} h=${MON_H}"
logv "Usable area: x=${WORK_X} y=${WORK_Y} w=${WORK_W} h=${WORK_H}"
logv "Requested: width=${REQ_WIDTH}% height=${REQ_HEIGHT}% h_anchor=${H_ANCHOR} h_pos=${H_POSITION}% v_anchor=${V_ANCHOR} v_pos=${V_POSITION}%"
logv "Target: x=${TARGET_X} y=${TARGET_Y} w=${TARGET_W} h=${TARGET_H}"

wmctrl -ir "${ACTIVE_WIN}" -b remove,maximized_vert,maximized_horz
wmctrl -ir "${ACTIVE_WIN}" -e "0,${TARGET_X},${TARGET_Y},${TARGET_W},${TARGET_H}"

logv "Done"
