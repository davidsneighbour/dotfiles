#!/bin/bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_LOG_FILE="${HOME}/.logs/desktop/wallpaper.log"
DEFAULT_MODE="auto"
DEFAULT_STYLE="fill"
DEFAULT_VERBOSE="false"

WALLPAPER_PATH=""
LOG_FILE="${DEFAULT_LOG_FILE}"
MODE="${DEFAULT_MODE}"
STYLE="${DEFAULT_STYLE}"
VERBOSE="${DEFAULT_VERBOSE}"

##
# Print help output.
#
# @returns {void}
##
print_help() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} --wallpaper "/absolute/path/to/image.jpg" [options]

Required:
  --wallpaper PATH       Absolute or relative path to the wallpaper image

Options:
  --mode MODE            Backend mode: auto | xfce | gnome | kde | sway | hyprland | feh
                         Default: ${DEFAULT_MODE}
  --style STYLE          Wallpaper style hint: fill | fit | stretch | center | tile
                         Default: ${DEFAULT_STYLE}
  --log-file PATH        Log file path
                         Default: ${DEFAULT_LOG_FILE}
  --verbose              Enable verbose output on CLI (always verbose to log file)
  --help                 Show this help message

Examples:
  ${SCRIPT_NAME} --wallpaper "${HOME}/Pictures/wallpapers/forest.jpg"
  ${SCRIPT_NAME} --wallpaper "./wall.jpg" --mode xfce --verbose
  ${SCRIPT_NAME} --wallpaper "${HOME}/Pictures/wall.jpg" --log-file "${HOME}/.logs/desktop/wallpaper.log"
EOF
}

##
# Print an error message and help output.
#
# @param {string} message Error message
# @returns {void}
##
fail_with_help() {
  local message="${1}"

  printf 'Error: %s\n\n' "${message}" >&2
  print_help >&2
  exit 1
}

##
# Write a timestamped log line.
#
# @param {string} level Log level
# @param {string} message Log message
# @returns {void}
##
log_message() {
  local level="${1}"
  local message="${2}"
  local timestamp

  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "$(dirname "${LOG_FILE}")"
  printf '[%s] [%s] %s\n' "${timestamp}" "${level}" "${message}" >>"${LOG_FILE}"

  if [[ "${VERBOSE}" == "true" ]]; then
    printf '[%s] [%s] %s\n' "${timestamp}" "${level}" "${message}"
  fi
}

##
# Resolve an absolute path from the provided wallpaper argument.
#
# @param {string} input_path Input file path
# @returns {void}
##
resolve_wallpaper_path() {
  local input_path="${1}"

  if command -v realpath >/dev/null 2>&1; then
    WALLPAPER_PATH="$(realpath "${input_path}")"
    return
  fi

  if command -v readlink >/dev/null 2>&1; then
    WALLPAPER_PATH="$(readlink -f "${input_path}")"
    return
  fi

  fail_with_help "Neither realpath nor readlink is available to resolve the wallpaper path."
}

##
# Check whether a command exists.
#
# @param {string} command_name Command name
# @returns {int}
##
have_command() {
  local command_name="${1}"
  command -v "${command_name}" >/dev/null 2>&1
}

##
# Convert a generic style name to feh options.
#
# @returns {void}
##
get_feh_style_flag() {
  case "${STYLE}" in
  fill)
    printf '%s' '--bg-fill'
    ;;
  fit)
    printf '%s' '--bg-max'
    ;;
  stretch)
    printf '%s' '--bg-scale'
    ;;
  center)
    printf '%s' '--bg-center'
    ;;
  tile)
    printf '%s' '--bg-tile'
    ;;
  *)
    printf '%s' '--bg-fill'
    ;;
  esac
}

##
# Convert a generic style name to XFCE image-style code.
#
# XFCE commonly uses integer style values.
# 0 none, 1 center, 2 tile, 3 stretch, 4 scale, 5 zoom, 6 spanning
#
# @returns {void}
##
get_xfce_style_value() {
  case "${STYLE}" in
  center)
    printf '%s' '1'
    ;;
  tile)
    printf '%s' '2'
    ;;
  stretch)
    printf '%s' '3'
    ;;
  fit)
    printf '%s' '4'
    ;;
  fill)
    printf '%s' '5'
    ;;
  *)
    printf '%s' '5'
    ;;
  esac
}

##
# Set wallpaper in XFCE via xfconf-query.
#
# @returns {int}
##
set_wallpaper_xfce() {
  local style_value
  local property_list
  local image_property
  local style_property
  local applied="false"

  if ! have_command xfconf-query; then
    log_message "ERROR" "xfconf-query is not available."
    return 1
  fi

  style_value="$(get_xfce_style_value)"
  property_list="$(xfconf-query --channel xfce4-desktop --list 2>/dev/null || true)"

  if [[ -z "${property_list}" ]]; then
    log_message "ERROR" "Could not read XFCE desktop properties."
    return 1
  fi

  while IFS= read -r image_property; do
    [[ -z "${image_property}" ]] && continue

    if [[ "${image_property}" == *"/last-image" ]]; then
      style_property="${image_property%/last-image}/image-style"
    else
      style_property="${image_property%/image-path}/image-style"
    fi

    log_message "INFO" "Setting XFCE property ${image_property} to ${WALLPAPER_PATH}"
    xfconf-query --channel xfce4-desktop --property "${image_property}" --set "${WALLPAPER_PATH}" >/dev/null 2>&1 || true

    if xfconf-query --channel xfce4-desktop --property "${style_property}" >/dev/null 2>&1; then
      log_message "INFO" "Setting XFCE style property ${style_property} to ${style_value}"
      xfconf-query --channel xfce4-desktop --property "${style_property}" --set "${style_value}" >/dev/null 2>&1 || true
    fi

    applied="true"
  done < <(printf '%s\n' "${property_list}" | grep -E '/(last-image|image-path)$' || true)

  if [[ "${applied}" != "true" ]]; then
    log_message "ERROR" "No XFCE wallpaper properties were found."
    return 1
  fi

  if have_command xfdesktop; then
    xfdesktop --reload >/dev/null 2>&1 || true
  fi

  log_message "INFO" "Wallpaper applied via XFCE."
  return 0
}

##
# Set wallpaper in GNOME-compatible desktops via gsettings.
#
# @returns {int}
##
set_wallpaper_gnome() {
  local wallpaper_uri

  if ! have_command gsettings; then
    log_message "ERROR" "gsettings is not available."
    return 1
  fi

  wallpaper_uri="file://${WALLPAPER_PATH}"

  gsettings set org.gnome.desktop.background picture-uri "${wallpaper_uri}" >/dev/null 2>&1 || return 1
  gsettings set org.gnome.desktop.background picture-uri-dark "${wallpaper_uri}" >/dev/null 2>&1 || true

  case "${STYLE}" in
  center | tile | stretch | fit | fill)
    gsettings set org.gnome.desktop.background picture-options "${STYLE}" >/dev/null 2>&1 || true
    ;;
  *)
    gsettings set org.gnome.desktop.background picture-options "zoom" >/dev/null 2>&1 || true
    ;;
  esac

  log_message "INFO" "Wallpaper applied via GNOME gsettings."
  return 0
}

##
# Set wallpaper in KDE Plasma via qdbus or qdbus6.
#
# @returns {int}
##
set_wallpaper_kde() {
  local dbus_tool=""
  local js

  if have_command qdbus6; then
    dbus_tool="qdbus6"
  elif have_command qdbus; then
    dbus_tool="qdbus"
  else
    log_message "ERROR" "Neither qdbus6 nor qdbus is available."
    return 1
  fi

  js="$(
    cat <<EOF
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
  var d = allDesktops[i];
  d.wallpaperPlugin = "org.kde.image";
  d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  d.writeConfig("Image", "file://${WALLPAPER_PATH}");
  d.writeConfig("FillMode", "2");
}
EOF
  )"

  "${dbus_tool}" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "${js}" >/dev/null 2>&1 || return 1
  log_message "INFO" "Wallpaper applied via KDE Plasma."
  return 0
}

##
# Set wallpaper in sway.
#
# @returns {int}
##
set_wallpaper_sway() {
  local sway_mode="fill"

  if ! have_command swaymsg; then
    log_message "ERROR" "swaymsg is not available."
    return 1
  fi

  case "${STYLE}" in
  fill)
    sway_mode="fill"
    ;;
  fit)
    sway_mode="fit"
    ;;
  stretch)
    sway_mode="stretch"
    ;;
  center)
    sway_mode="center"
    ;;
  tile)
    sway_mode="tile"
    ;;
  *)
    sway_mode="fill"
    ;;
  esac

  swaymsg "output * bg '${WALLPAPER_PATH}' ${sway_mode}" >/dev/null 2>&1 || return 1
  log_message "INFO" "Wallpaper applied via sway."
  return 0
}

##
# Set wallpaper in Hyprland using hyprctl and hyprpaper if available.
#
# @returns {int}
##
set_wallpaper_hyprland() {
  if have_command hyprctl; then
    hyprctl hyprpaper preload "${WALLPAPER_PATH}" >/dev/null 2>&1 || true
    hyprctl hyprpaper wallpaper ",${WALLPAPER_PATH}" >/dev/null 2>&1 || true
    log_message "INFO" "Wallpaper applied via Hyprland hyprpaper control."
    return 0
  fi

  log_message "ERROR" "hyprctl is not available."
  return 1
}

##
# Set wallpaper via feh on X11.
#
# @returns {int}
##
set_wallpaper_feh() {
  local feh_style

  if ! have_command feh; then
    log_message "ERROR" "feh is not available."
    return 1
  fi

  feh_style="$(get_feh_style_flag)"
  feh "${feh_style}" "${WALLPAPER_PATH}" >/dev/null 2>&1 || return 1

  log_message "INFO" "Wallpaper applied via feh."
  return 0
}

##
# Detect the most suitable backend from the current environment.
#
# @returns {void}
##
detect_mode() {
  local desktop_lower
  local session_lower

  desktop_lower="$(printf '%s' "${XDG_CURRENT_DESKTOP:-}" | tr '[:upper:]' '[:lower:]')"
  session_lower="$(printf '%s' "${DESKTOP_SESSION:-}" | tr '[:upper:]' '[:lower:]')"

  if [[ "${desktop_lower}" == *"xfce"* ]] || [[ "${session_lower}" == *"xfce"* ]]; then
    MODE="xfce"
    return
  fi

  if [[ "${desktop_lower}" == *"gnome"* ]] || [[ "${desktop_lower}" == *"ubuntu"* ]] || [[ "${desktop_lower}" == *"cinnamon"* ]] || [[ "${desktop_lower}" == *"mate"* ]]; then
    MODE="gnome"
    return
  fi

  if [[ "${desktop_lower}" == *"kde"* ]] || [[ "${desktop_lower}" == *"plasma"* ]] || [[ "${session_lower}" == *"plasma"* ]]; then
    MODE="kde"
    return
  fi

  if [[ "${desktop_lower}" == *"sway"* ]] || [[ -n "${SWAYSOCK:-}" ]]; then
    MODE="sway"
    return
  fi

  if [[ "${desktop_lower}" == *"hyprland"* ]] || [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    MODE="hyprland"
    return
  fi

  if [[ "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
    MODE="feh"
    return
  fi

  MODE="feh"
}

##
# Parse CLI arguments.
#
# @param {string[]} args CLI arguments
# @returns {void}
##
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "${1}" in
    --wallpaper)
      [[ $# -lt 2 ]] && fail_with_help "--wallpaper requires a value."
      resolve_wallpaper_path "${2}"
      shift 2
      ;;
    --mode)
      [[ $# -lt 2 ]] && fail_with_help "--mode requires a value."
      MODE="${2}"
      shift 2
      ;;
    --style)
      [[ $# -lt 2 ]] && fail_with_help "--style requires a value."
      STYLE="${2}"
      shift 2
      ;;
    --log-file)
      [[ $# -lt 2 ]] && fail_with_help "--log-file requires a value."
      LOG_FILE="${2}"
      shift 2
      ;;
    --verbose)
      VERBOSE="true"
      shift
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      fail_with_help "Unknown argument: ${1}"
      ;;
    esac
  done
}

##
# Validate final runtime configuration.
#
# @returns {void}
##
validate_config() {
  if [[ -z "${WALLPAPER_PATH}" ]]; then
    fail_with_help "--wallpaper is required."
  fi

  if [[ ! -f "${WALLPAPER_PATH}" ]]; then
    fail_with_help "Wallpaper file does not exist: ${WALLPAPER_PATH}"
  fi

  case "${MODE}" in
  auto | xfce | gnome | kde | sway | hyprland | feh) ;;
  *)
    fail_with_help "Unsupported mode: ${MODE}"
    ;;
  esac

  case "${STYLE}" in
  fill | fit | stretch | center | tile) ;;
  *)
    fail_with_help "Unsupported style: ${STYLE}"
    ;;
  esac
}

##
# Run the selected wallpaper backend.
#
# @returns {int}
##
apply_wallpaper() {
  if [[ "${MODE}" == "auto" ]]; then
    detect_mode
    log_message "INFO" "Auto-detected wallpaper mode: ${MODE}"
  fi

  case "${MODE}" in
  xfce)
    set_wallpaper_xfce
    ;;
  gnome)
    set_wallpaper_gnome
    ;;
  kde)
    set_wallpaper_kde
    ;;
  sway)
    set_wallpaper_sway
    ;;
  hyprland)
    set_wallpaper_hyprland
    ;;
  feh)
    set_wallpaper_feh
    ;;
  *)
    log_message "ERROR" "Unsupported runtime mode: ${MODE}"
    return 1
    ;;
  esac
}

##
# Main entry point.
#
# @param {string[]} args CLI arguments
# @returns {void}
##
main() {
  parse_args "$@"
  validate_config

  log_message "INFO" "Requested wallpaper: ${WALLPAPER_PATH}"
  log_message "INFO" "Requested mode: ${MODE}"
  log_message "INFO" "Requested style: ${STYLE}"

  if ! apply_wallpaper; then
    log_message "ERROR" "Failed to apply wallpaper."
    printf 'Failed to apply wallpaper. See log: %s\n' "${LOG_FILE}" >&2
    exit 1
  fi

  log_message "INFO" "Wallpaper update completed successfully."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
