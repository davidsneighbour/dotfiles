#!/bin/bash

set -Eeuo pipefail

# rofi-move-window-to-workspace.sh
# - Shows a rofi menu listing XFCE/xfwm4 workspaces (1-based).
# - Moves the currently active window to the selected workspace AND switches to it.
# - Delegates the actual move/switch to your workspace management script:
#   workspace-move-window.sh --to <N> --follow
#
# Requirements:
# - rofi
# - wmctrl (to list workspaces reliably)
# - your workspace-move-window.sh from earlier

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} [--move-script <path>] [--rofi-theme <name|path>] [--prompt <text>] [--verbose]
  ${SCRIPT_NAME} --help

Options:
  --move-script <path>   Path to workspace-move-window.sh (default: same directory as this script).
  --rofi-theme <value>   Passed to rofi as: -theme <value> (optional).
  --prompt <text>        Prompt label shown by rofi (default: "Move to workspace").
  --verbose              Verbose debug output to stderr.
  --help                 Show this help.

Behaviour:
  * Workspaces are displayed as 1-based indexes.
  * Selection can be made by keyboard or mouse.
  * On selection, the active window is moved to that workspace and focus follows.

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --move-script "\$HOME/.dotfiles/bashrc/helpers/workspace-move-window.sh"
  ${SCRIPT_NAME} --rofi-theme "gruvbox-dark" --verbose

EOF
}

die() {
  local msg="$1"
  echo "ERROR: ${msg}" >&2
  echo >&2
  usage >&2
  exit 1
}

logv() {
  local msg="$1"
  if [[ "${VERBOSE}" == "1" ]]; then
    echo "DEBUG: ${msg}" >&2
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

VERBOSE="0"
MOVE_SCRIPT=""
ROFI_THEME=""
PROMPT="Move to workspace"

# Print help if called without parameters? (Not required here; interactive default is useful.)
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
  --move-script)
    shift
    [[ $# -gt 0 ]] || die "--move-script requires a value"
    MOVE_SCRIPT="$1"
    shift
    ;;
  --rofi-theme)
    shift
    [[ $# -gt 0 ]] || die "--rofi-theme requires a value"
    ROFI_THEME="$1"
    shift
    ;;
  --prompt)
    shift
    [[ $# -gt 0 ]] || die "--prompt requires a value"
    PROMPT="$1"
    shift
    ;;
  *)
    die "Unknown option: $1"
    ;;
  esac
done

need_cmd rofi || die "rofi is not installed. Install with: sudo apt install rofi"
need_cmd wmctrl || die "wmctrl is not installed. Install with: sudo apt install wmctrl"

if [[ -z "${MOVE_SCRIPT}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  MOVE_SCRIPT="/home/patrick/.dotfiles/bin/workspaces/wm-wmanagement.sh"
fi

[[ -f "${MOVE_SCRIPT}" ]] || die "Move script not found: ${MOVE_SCRIPT}"
[[ -x "${MOVE_SCRIPT}" ]] || die "Move script is not executable: ${MOVE_SCRIPT}"

logv "Using move script: ${MOVE_SCRIPT}"

# Read workspace definitions from TOML next to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOML_FILE="${SCRIPT_DIR}/config.toml"

[[ -f "${TOML_FILE}" ]] || die "Workspace TOML file not found: ${TOML_FILE}"

menu="$(
  awk '
    BEGIN { idx=0; title=""; icon="" }

    /^\[\[workspace\]\]/ {
      if (title != "") {
        idx++
        printf "%d - <span font=\"Lucide 12\">%s</span> - %s\n", idx, icon, title
      }
      title=""; icon=""
      next
    }

    /^title[[:space:]]*=/ {
      sub(/^title[[:space:]]*=[[:space:]]*"/, "")
      sub(/"$/, "")
      title=$0
      next
    }

    /^icon[[:space:]]*=/ {
      sub(/^icon[[:space:]]*=[[:space:]]*"/, "")
      sub(/"$/, "")
      icon=$0
      next
    }

    END {
      if (title != "") {
        idx++
        printf "%d - <span font=\"Lucide 12\">%s</span> - %s\n", idx, icon, title
      }
    }
  ' "${TOML_FILE}"
)"

[[ -n "${menu}" ]] || die "Could not read workspaces via wmctrl -d"

logv "$(printf "Menu:\n%s\n" "${menu}")"

rofi_args=(-dmenu -i -markup-rows -p "${PROMPT}")
if [[ -n "${ROFI_THEME}" ]]; then
  rofi_args+=(-theme "${ROFI_THEME}")
fi

selection="$(printf '%s\n' "${menu}" | rofi "${rofi_args[@]}")" || true

# User cancelled (ESC or empty)
if [[ -z "${selection}" ]]; then
  logv "No selection (cancelled)."
  exit 0
fi

logv "Selection: ${selection}"

# Extract leading workspace number (1-based)
target_ws="$(printf '%s' "${selection}" | awk '{print $1}')"
[[ "${target_ws}" =~ ^[0-9]+$ ]] || die "Could not parse workspace index from selection: ${selection}"
[[ "${target_ws}" -ge 1 ]] || die "Workspace index must be >= 1, got: ${target_ws}"

logv "Target workspace (1-based): ${target_ws}"

# Move active window and follow
# (Your move script already handles 1-based -> 0-based internally.)
if ! "${MOVE_SCRIPT}" --to "${target_ws}" --follow $([[ "${VERBOSE}" == "1" ]] && printf '%s' "--verbose"); then
  die "Failed to move active window to workspace ${target_ws}"
fi

logv "Done."
