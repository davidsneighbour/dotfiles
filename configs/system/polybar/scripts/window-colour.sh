#!/bin/bash
set -euo pipefail

print_help() {
  cat <<'EOF'
polybar-window-colour

Print a Polybar-formatted label whose colour depends on a window's state.
Colours are read from a Polybar INI config file (e.g. [colours] section).

Usage:
  polybar-window-colour \
    --config "/home/user/.config/polybar/config.ini" \
    --wmclass "signal.Signal" \
    --label "Signal" \
    --section "colours" \
    --hidden-key "foreground" \
    --shown-key "selection"

Notes:
- If no window found or it is hidden/minimised -> hidden colour.
- If window is visible -> shown colour.
- If a colour key is missing -> falls back to #ffffff (hidden) and #ff5500 (shown).
EOF
}

CONFIG=""
WMCLASS=""
LABEL=""
SECTION="colours"
HIDDEN_KEY="foreground"
SHOWN_KEY="selection"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --config)
    CONFIG="${2:-}"
    shift 2
    ;;
  --wmclass)
    WMCLASS="${2:-}"
    shift 2
    ;;
  --label)
    LABEL="${2:-}"
    shift 2
    ;;
  --section)
    SECTION="${2:-}"
    shift 2
    ;;
  --hidden-key)
    HIDDEN_KEY="${2:-}"
    shift 2
    ;;
  --shown-key)
    SHOWN_KEY="${2:-}"
    shift 2
    ;;
  --help)
    print_help
    exit 0
    ;;
  *)
    echo "Error: Unknown option: $1" >&2
    print_help >&2
    exit 2
    ;;
  esac
done

if [[ -z "${CONFIG}" || -z "${WMCLASS}" || -z "${LABEL}" ]]; then
  echo "Error: --config, --wmclass, --label are required" >&2
  print_help >&2
  exit 2
fi

if [[ ! -f "${CONFIG}" ]]; then
  echo "Error: Config not found: ${CONFIG}" >&2
  exit 2
fi

# Reads a key from an INI section. Returns empty string if not found.
ini_get() {
  local file="$1"
  local section="$2"
  local key="$3"

  awk -v section="${section}" -v key="${key}" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

    BEGIN { in_section = 0 }

    {
      line = $0
      sub(/[;#].*$/, "", line)     # strip comments
      line = trim(line)
      if (line == "") next

      # section header
      if (substr(line, 1, 1) == "[" && substr(line, length(line), 1) == "]") {
        in_section = (line == "[" section "]")
        next
      }

      if (!in_section) next

      pos = index(line, "=")
      if (pos == 0) next

      k = trim(substr(line, 1, pos - 1))
      if (k != key) next

      v = trim(substr(line, pos + 1))
      print v
      exit
    }
  ' "${file}"
}

# Polybar config sometimes uses ${xrdb:...} expansions, but your colours are literal hex.
color_hidden="$(ini_get "${CONFIG}" "${SECTION}" "${HIDDEN_KEY}")"
color_shown="$(ini_get "${CONFIG}" "${SECTION}" "${SHOWN_KEY}")"

# Fallbacks
[[ -n "${color_hidden}" ]] || color_hidden="#F8F8F2"
[[ -n "${color_shown}" ]] || color_shown="#414D58"

wid="$(
  wmctrl -lx 2>/dev/null |
    awk -v cls="${WMCLASS}" 'BEGIN{IGNORECASE=1} $3==cls {print $1; exit}'
)"

# Default to hidden colour if window not found
if [[ -z "${wid}" ]]; then
  printf '%%{F%s}%s%%{F-}\n' "${color_hidden}" "${LABEL}"
  exit 0
fi

is_iconic="0"
if xprop -id "${wid}" WM_STATE 2>/dev/null | grep -q "Iconic"; then
  is_iconic="1"
fi

is_hidden="0"
if xprop -id "${wid}" _NET_WM_STATE 2>/dev/null | grep -q "_NET_WM_STATE_HIDDEN"; then
  is_hidden="1"
fi

if [[ "${is_iconic}" == "1" || "${is_hidden}" == "1" ]]; then
  printf '%%{F%s}%s%%{F-}\n' "${color_hidden}" "${LABEL}"
else
  printf '%%{F%s}%s%%{F-}\n' "${color_shown}" "${LABEL}"
fi
