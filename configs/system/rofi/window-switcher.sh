#!/bin/bash

##
# Print help for the window switcher script.
#
# Options:
#   --help       Show help.
#
# Behaviour:
#   Prints usage information for the standalone script.
#
# Examples:
#   ./window-switcher.sh --help
#   ./window-switcher.sh --scope all
#   ./window-switcher.sh --scope workspace
#
window_switcher_help() {
  cat <<EOF
Usage: $(basename "$0") [--scope all|workspace] [--help]

Show a rofi-based window switcher.

Options:
  --scope all          Show windows from all workspaces.
  --scope workspace    Show windows only from the current workspace.
  --help               Show this help message.

Examples:
  $(basename "$0") --scope all
  $(basename "$0") --scope workspace

Notes:
  * Default scope is: all
  * Requires: rofi
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
#   window_switcher_requirements
#
window_switcher_requirements() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: ${FUNCNAME[0]}

Check whether required commands for the window switcher are available.
EOF
    return 0
  fi

  if ! command -v rofi >/dev/null 2>&1; then
    printf 'Error: rofi is not installed or not in PATH.\n' >&2
    return 1
  fi
}

##
# Build shared rofi arguments for window switching.
#
# Options:
#   --help       Show help.
#
# Output:
#   Prints one rofi argument per line for safe loading into an array.
#
# Examples:
#   mapfile -t args < <(window_switcher_rofi_args)
#
window_switcher_rofi_args() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: ${FUNCNAME[0]}

Print shared rofi arguments for the window switcher, one per line.
EOF
    return 0
  fi

  cat <<'EOF'
-show-icons
-kb-cancel
Alt+Escape,Escape
-kb-row-down
Alt+Tab,Down
-kb-row-up
Alt+ISO_Left_Tab,Up
-window-match-fields
title,class
-theme-str
listview { lines: 12; dynamic: false; scrollbar: true; } element { padding: 6px; } element-text { vertical-align: 0.5; }
EOF
}

##
# Show rofi window switcher for all windows.
#
# Options:
#   --help       Show help.
#
# Examples:
#   window_switcher_all
#
window_switcher_all() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: ${FUNCNAME[0]}

Show all windows from all workspaces in rofi.
EOF
    return 0
  fi

  local -a rofi_args=()
  mapfile -t rofi_args < <(window_switcher_rofi_args) || {
    printf 'Error: failed to build rofi arguments.\n' >&2
    return 1
  }

  rofi \
    -show window \
    -window-format "{w:10} {c:18} {t}" \
    "${rofi_args[@]}"
}

##
# Show rofi window switcher for current workspace only.
#
# Options:
#   --help       Show help.
#
# Examples:
#   window_switcher_workspace
#
window_switcher_workspace() {
  if [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: ${FUNCNAME[0]}

Show only windows from the current workspace in rofi.
EOF
    return 0
  fi

  local -a rofi_args=()
  mapfile -t rofi_args < <(window_switcher_rofi_args) || {
    printf 'Error: failed to build rofi arguments.\n' >&2
    return 1
  }

  G_MESSAGES_DEBUG=Timings rofi \
    -show windowcd \
    -window-format "{c:20} {t}" \
    "${rofi_args[@]}"
}

##
# Main entry point for standalone execution.
#
# Options:
#   --scope all|workspace   Scope of windows to display.
#   --help                  Show help.
#
# Behaviour:
#   Parses arguments and launches the requested rofi window switcher.
#
# Examples:
#   $(basename "$0") --scope all
#   $(basename "$0") --scope workspace
#
window_switcher_main() {
  local scope="all"

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --scope)
      if [[ $# -lt 2 ]]; then
        printf 'Error: --scope requires a value.\n\n' >&2
        window_switcher_help >&2
        return 1
      fi
      scope="$2"
      shift 2
      ;;
    --help)
      window_switcher_help
      return 0
      ;;
    *)
      printf 'Error: unknown argument: %s\n\n' "$1" >&2
      window_switcher_help >&2
      return 1
      ;;
    esac
  done

  window_switcher_requirements || return 1

  # fallback safety (optional but explicit)
  if [[ -z "${scope}" ]]; then
    scope="all"
  fi

  case "${scope}" in
  all)
    window_switcher_all
    ;;
  workspace)
    window_switcher_workspace
    ;;
  *)
    printf 'Error: invalid scope: %s\n\n' "${scope}" >&2
    window_switcher_help >&2
    return 1
    ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  window_switcher_main "$@"
fi
