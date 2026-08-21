#!/bin/bash

set -Eeuo pipefail

show_help() {
  cat <<'EOF'
Usage:
  window-debug.sh [--editor COMMAND] [--output FILE] [--print] [--verbose] [--quiet]
  window-debug.sh --help

Description:
  Select one X11 window, collect useful xprop and xwininfo information, write it
  to a file, and optionally open that file in an editor.

Options:
  --editor COMMAND  Editor command used to open the report.
                    Defaults to VISUAL, EDITOR, subl, xdg-open, or no editor.
  --output FILE     Write the report to FILE instead of a temporary file.
  --print           Print the report path after writing it.
  --verbose         Print progress messages.
  --quiet           Suppress progress messages.
  --help            Show this help.

Requirements:
  - xprop
  - xwininfo
EOF
}

die() {
  printf 'Error: %s\n' "${*}" >&2
  exit 1
}

info() {
  if [[ "${verbose_mode}" == 'true' ]]; then
    printf '%s\n' "${*}" >&2
  fi
}

require_command() {
  local command_name="${1}"

  command -v "${command_name}" >/dev/null 2>&1 \
    || die "Required command not found: ${command_name}"
}

resolve_editor() {
  local configured_editor="${1}"

  if [[ -n "${configured_editor}" ]]; then
    printf '%s\n' "${configured_editor}"
    return 0
  fi

  if [[ -n "${VISUAL:-}" ]]; then
    printf '%s\n' "${VISUAL}"
    return 0
  fi

  if [[ -n "${EDITOR:-}" ]]; then
    printf '%s\n' "${EDITOR}"
    return 0
  fi

  if command -v subl >/dev/null 2>&1; then
    printf 'subl\n'
    return 0
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    printf 'xdg-open\n'
    return 0
  fi

  return 1
}

main() {
  local editor=''
  local output_file=''
  local print_path='false'
  local quiet_mode='false'
  verbose_mode='false'

  if [[ "${DNB_VERBOSE:-}" == '1' ]]; then
    verbose_mode='true'
  fi

  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
    --editor)
      [[ -n "${2:-}" ]] || die "--editor requires a command."
      editor="${2}"
      shift 2
      ;;
    --output)
      [[ -n "${2:-}" ]] || die "--output requires a file path."
      output_file="${2}"
      shift 2
      ;;
    --print)
      print_path='true'
      shift
      ;;
    --verbose)
      verbose_mode='true'
      export DNB_VERBOSE='1'
      shift
      ;;
    --quiet)
      quiet_mode='true'
      shift
      ;;
    --help)
      show_help
      return 0
      ;;
    *)
      show_help >&2
      die "Unknown argument: ${1}"
      ;;
    esac
  done

  if [[ "${quiet_mode}" == 'true' ]]; then
    verbose_mode='false'
    unset DNB_VERBOSE
  fi

  require_command xprop
  require_command xwininfo

  local window_info
  local window_id

  info 'Select a window with the mouse cursor.'
  window_info="$(xwininfo)" || die 'Window selection cancelled.'

  window_id="$(
    printf '%s\n' "${window_info}" \
      | awk '/Window id:/ { print $4; exit }'
  )"

  [[ -n "${window_id}" ]] \
    || die 'Could not determine the selected window ID.'

  if [[ -z "${output_file}" ]]; then
    output_file="$(mktemp --tmpdir window-debug.XXXXXXXX.txt)"
  else
    mkdir -p "$(dirname "${output_file}")"
  fi

  {
    printf 'Window debug information\n'
    printf '========================\n\n'
    printf 'Generated: %s\n' "$(date --iso-8601=seconds)"
    printf 'Window ID: %s\n\n' "${window_id}"

    printf 'Useful properties\n'
    printf '=================\n\n'

    xprop \
      -id "${window_id}" \
      WM_CLASS \
      WM_NAME \
      WM_WINDOW_ROLE \
      _NET_WM_NAME \
      _NET_WM_PID \
      _NET_WM_WINDOW_TYPE \
      _NET_WM_DESKTOP \
      _NET_WM_STATE \
      WM_CLIENT_MACHINE \
      WM_TRANSIENT_FOR

    printf '\n\nWindow geometry\n'
    printf '===============\n\n'
    printf '%s\n' "${window_info}"

    printf '\n\nFull xprop output\n'
    printf '=================\n\n'
    xprop -id "${window_id}"
  } >"${output_file}"

  info "Wrote ${output_file}"

  local resolved_editor=''
  if resolved_editor="$(resolve_editor "${editor}")"; then
    info "Opening ${output_file} with ${resolved_editor}"
    "${resolved_editor}" "${output_file}" >/dev/null 2>&1 &
  else
    print_path='true'
  fi

  if [[ "${print_path}" == 'true' ]]; then
    printf '%s\n' "${output_file}"
  fi
}

main "${@}"
