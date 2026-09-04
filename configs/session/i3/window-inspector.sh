#!/bin/bash
#
# Click-to-select window inspector. Bound to Ctrl+Shift+Alt+I (see
# configs/session/i3/configs/applications.conf). Lets you click any window
# to see its WM_CLASS, WM_WINDOW_ROLE, title, PID, geometry, and desktop —
# the details i3 for_window/assign match rules need — in a floating
# terminal, without leaving the keyboard/mouse to open a real terminal.
#
# The floating terminal is matched by configs/session/i3/configs/rules.conf
# on WM_WINDOW_ROLE (set via `terminator --role`, below), not on title or
# class, so it never collides with a normal terminator window.

##
# Print help for the window inspector script.
#
# Options:
#   --help       Show help.
#
# Behaviour:
#   Prints usage information for the standalone script.
#
# Examples:
#   ./window-inspector.sh --help
#
window_inspector_help() {
  cat <<EOF
Usage: $(basename "$0") [--help]

Click a window, then show its WM_CLASS/role/title/PID/geometry in a
floating terminal — for finding the match criteria an i3 for_window or
assign rule needs.

Options:
  --help               Show this help message.

Examples:
  $(basename "$0")

Notes:
  * Requires: xdotool, wmctrl, xprop, terminator
  * Bound to Ctrl+Shift+Alt+I in configs/session/i3/configs/applications.conf
EOF
}

##
# Verify required commands exist.
#
# Options:
#   --help       Show help.
#
# Behaviour:
#   Checks whether required external commands are available.
#   Returns non-zero if a dependency is missing.
#
# Examples:
#   window_inspector_requirements
#
window_inspector_requirements() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: ${FUNCNAME[0]}

Check whether required commands for the window inspector are available.
EOF
    return 0
  fi

  local command_name

  for command_name in xdotool wmctrl xprop terminator; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
      printf 'Error: %s is not installed or not in PATH.\n' "${command_name}" >&2
      return 1
    fi
  done
}

##
# Print collected details for one window id to stdout.
#
# Options:
#   --help       Show help.
#
# Arguments:
#   $1  Decimal X11 window id (as returned by `xdotool selectwindow`).
#
# Examples:
#   window_inspector_report 12582915
#
window_inspector_report() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: ${FUNCNAME[0]} <window_id>

Print wmctrl/xprop/xdotool details for the given decimal X11 window id.
EOF
    return 0
  fi

  local window_id="${1:?window id required}"
  local hex_id
  local wm_class_line
  local instance_name=""
  local class_name=""
  local wmctrl_line=""
  local wmctrl_id

  hex_id="$(printf '0x%08x' "${window_id}")"

  printf 'Window id: %s (%s)\n\n' "${window_id}" "${hex_id}"

  printf -- '--- xdotool ---\n'
  printf 'Name:     %s\n' "$(xdotool getwindowname "${window_id}" 2>/dev/null)"
  printf 'PID:      %s\n' "$(xdotool getwindowpid "${window_id}" 2>/dev/null)"
  printf 'Geometry: %s\n' "$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g')"
  printf '\n'

  printf -- '--- xprop ---\n'
  xprop -id "${hex_id}" WM_CLASS WM_WINDOW_ROLE WM_NAME _NET_WM_PID 2>/dev/null
  printf '\n'

  printf -- '--- wmctrl (desktop pid class client title) ---\n'
  while IFS= read -r wmctrl_line; do
    wmctrl_id="${wmctrl_line%% *}"
    if ((wmctrl_id == window_id)); then
      printf '%s\n' "${wmctrl_line}"
    fi
  done < <(wmctrl -lxp)
  printf '\n'

  wm_class_line="$(xprop -id "${hex_id}" WM_CLASS 2>/dev/null)"
  instance_name="$(printf '%s' "${wm_class_line}" | sed -n 's/.*"\([^"]*\)", "[^"]*".*/\1/p')"
  class_name="$(printf '%s' "${wm_class_line}" | sed -n 's/.*"[^"]*", "\([^"]*\)".*/\1/p')"

  if [[ -n "${class_name}" ]]; then
    printf -- '--- suggested i3 match ---\n'
    printf '[class="%s" instance="%s"]\n' "${class_name}" "${instance_name}"
  fi
}

##
# Interactively select a window and show its details in a floating terminal.
#
# Options:
#   --help       Show help.
#
# Examples:
#   window_inspector_run
#
window_inspector_run() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: ${FUNCNAME[0]}

Prompt to click a window, then show its details in a floating terminal.
EOF
    return 0
  fi

  local script_path
  local window_id

  script_path="$(readlink -f "${BASH_SOURCE[0]}")"

  window_id="$(xdotool selectwindow 2>/dev/null)" || {
    printf 'Error: window selection cancelled or failed.\n' >&2
    return 1
  }

  if [[ -z "${window_id}" ]]; then
    printf 'Error: no window id captured.\n' >&2
    return 1
  fi

  terminator \
    --role="window-inspector" \
    -T "Window inspector" \
    -x "${script_path}" --report "${window_id}"
}

##
# Main entry point for standalone execution.
#
# Options:
#   --help              Show help.
#   --report <id>       Print the report for <id> and wait for a keypress
#                        (internal — this is what the floating terminal runs).
#
# Behaviour:
#   Parses arguments and either prints one window's report (used internally
#   by the floating terminal itself) or launches the interactive picker.
#
# Examples:
#   $(basename "$0")
#
window_inspector_main() {
  case "${1:-}" in
  --help)
    window_inspector_help
    return 0
    ;;
  --report)
    window_inspector_report "${2:?window id required}"
    printf '\nPress any key to close...'
    read -n 1 -s -r
    return 0
    ;;
  '')
    window_inspector_requirements || return 1
    window_inspector_run
    return $?
    ;;
  *)
    printf 'Error: unknown argument: %s\n\n' "$1" >&2
    window_inspector_help >&2
    return 1
    ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  window_inspector_main "$@"
fi
