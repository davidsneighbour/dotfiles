#!/bin/bash
# wm-detect.sh
# https://chatgpt.com/c/6998ea34-4be8-8398-8414-5a7f2c00efd5
#
# Detect the current X11 window manager via EWMH:
#   _NET_SUPPORTING_WM_CHECK + _NET_WM_NAME
#
# Usage:
#   ./wm-detect.sh
#   ./wm-detect.sh --verbose
#   ./wm-detect.sh --validate i3
#
# Exit codes:
#   0  success (and validate matched if used)
#   1  detection failed or validate did not match
#   2  invalid arguments / usage error

set -euo pipefail

print_help() {
  cat <<'EOF'
wm-detect.sh - detect current X11 window manager (EWMH)

Usage:
  wm-detect.sh [--verbose] [--validate <wm-name>] [--help]

Options:
  --verbose
      Print debugging details to stderr.

  --validate <wm-name>
      Validate that the detected window manager matches <wm-name>,
      case-insensitively. Example: --validate i3 matches "I3" and "i3".

  --help
      Show this help.

Output:
  Prints the detected window manager name to stdout on success.

Exit codes:
  0  success (and validate matched if used)
  1  detection failed or validate did not match
  2  invalid arguments / usage error
EOF
}

log_verbose() {
  if [[ "${VERBOSE}" == "1" ]]; then
    # shellcheck disable=SC2154
    printf '%s\n' "${*}" >&2
  fi
}

to_lower() {
  # Locale-stable lowercase conversion
  LC_ALL=C tr '[:upper:]' '[:lower:]'
}

require_cmd() {
  local cmd="${1}"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    printf 'ERROR: required command not found: %s\n' "${cmd}" >&2
    return 1
  fi
}

get_wm_name() {
  # Method 1: xprop on root window using EWMH.
  local wm_window=""
  local wm_name_line=""
  local wm_name=""

  require_cmd xprop

  log_verbose "Querying _NET_SUPPORTING_WM_CHECK on root window..."
  wm_window="$(xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | awk '{print $5}' || true)"

  if [[ -z "${wm_window}" || "${wm_window}" == "0x0" ]]; then
    log_verbose "No WM window id found (wm_window='${wm_window}')."
    return 1
  fi

  log_verbose "WM window id: ${wm_window}"
  log_verbose "Querying _NET_WM_NAME for WM window id..."

  wm_name_line="$(xprop -id "${wm_window}" _NET_WM_NAME 2>/dev/null || true)"

  # Typical format:
  #   _NET_WM_NAME(UTF8_STRING) = "i3"
  # or:
  #   _NET_WM_NAME = "Xfwm4"
  wm_name="$(printf '%s' "${wm_name_line}" | sed -E 's/.*= "([^"]+)".*/\1/' || true)"

  if [[ -z "${wm_name}" || "${wm_name}" == "${wm_name_line}" ]]; then
    log_verbose "Failed to parse WM name from line: ${wm_name_line}"
    return 1
  fi

  log_verbose "Detected WM name: ${wm_name}"
  printf '%s\n' "${wm_name}"
}

VERBOSE="0"
VALIDATE=""

# Arg parsing
if [[ "${#}" -eq 0 ]]; then
  :
else
  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
    --help)
      print_help
      exit 0
      ;;
    --verbose)
      VERBOSE="1"
      shift
      ;;
    --validate)
      shift
      if [[ "${#}" -lt 1 || -z "${1:-}" ]]; then
        printf 'ERROR: --validate requires a value\n\n' >&2
        print_help >&2
        exit 2
      fi
      VALIDATE="${1}"
      shift
      ;;
    *)
      printf 'ERROR: unknown option: %s\n\n' "${1}" >&2
      print_help >&2
      exit 2
      ;;
    esac
  done
fi

WM="$(get_wm_name)" || {
  printf 'ERROR: could not detect window manager (X11/EWMH)\n' >&2
  exit 1
}

# Always print WM name
printf '%s\n' "${WM}"

if [[ -n "${VALIDATE}" ]]; then
  WM_LC="$(printf '%s' "${WM}" | to_lower)"
  VALIDATE_LC="$(printf '%s' "${VALIDATE}" | to_lower)"

  log_verbose "Validating: detected='${WM_LC}' expected='${VALIDATE_LC}'"

  if [[ "${WM_LC}" == "${VALIDATE_LC}" ]]; then
    exit 0
  fi

  # Validation failed
  exit 1
fi

exit 0
