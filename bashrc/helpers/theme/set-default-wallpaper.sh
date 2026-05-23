#!/bin/bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DOTFILES_PATH="${HOME}/.dotfiles"
WALLPAPER_HELPER="${DOTFILES_PATH}/bashrc/helpers/theme/set-wallpaper.sh"

show_help() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} [--verbose] [--help]

Description:
  Checks for a default wallpaper at:
    ${DOTFILES_PATH}/assets/wallpaper.jpg
    ${DOTFILES_PATH}/assets/wallpaper.png

  If one exists, it calls:
    ${WALLPAPER_HELPER} --wallpaper <file>

Options:
  --verbose   Show detailed output.
  --help      Show this help message.
EOF
}

log_info() {
  local message="${1}"

  if [[ "${VERBOSE}" == "1" ]]; then
    printf 'Info: %s\n' "${message}"
  fi
}

log_error() {
  local message="${1}"

  printf 'Error: %s\n' "${message}" >&2
}

main() {
  VERBOSE="0"

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    --verbose)
      VERBOSE="1"
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      log_error "Unknown option: ${1}"
      show_help
      exit 1
      ;;
    esac
  done

  if [[ ! -x "${WALLPAPER_HELPER}" ]]; then
    log_error "Wallpaper helper is missing or not executable: ${WALLPAPER_HELPER}"
    show_help
    exit 1
  fi

  local wallpaper_path=""

  if [[ -f "${DOTFILES_PATH}/assets/wallpaper.jpg" ]]; then
    wallpaper_path="${DOTFILES_PATH}/assets/wallpaper.jpg"
  elif [[ -f "${DOTFILES_PATH}/assets/wallpaper.png" ]]; then
    wallpaper_path="${DOTFILES_PATH}/assets/wallpaper.png"
  else
    log_info "No default wallpaper found."
    exit 0
  fi

  log_info "Setting wallpaper: ${wallpaper_path}"

  if [[ "${VERBOSE}" == "1" ]]; then
    "${WALLPAPER_HELPER}" --wallpaper "${wallpaper_path}" --verbose
  else
    "${WALLPAPER_HELPER}" --wallpaper "${wallpaper_path}"
  fi
}

main "$@"
