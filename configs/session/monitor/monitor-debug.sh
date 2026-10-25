#!/bin/bash

set -euo pipefail

show_help() {
  local script_name
  script_name="$(basename "$0")"

  cat <<HELP
Usage:
  ${script_name} --check
  ${script_name} --help

Options:
  --check   Print monitor, DPI, XFCE, Xresources, fontconfig, and Chrome scaling diagnostics.
  --help    Show this help output.
HELP
}

run_check() {
  echo "## xrandr monitors"
  xrandr --listmonitors || true
  echo

  echo "## xrandr verbose for DP-1"
  xrandr --verbose | sed -n '/^DP-1 /,/^[A-Z0-9-]\+ connected/p'
  echo

  echo "## xdpyinfo dimensions and resolution"
  xdpyinfo | grep -E 'dimensions|resolution'
  echo

  echo "## Xresources DPI / font settings"
  xrdb -query | grep -Ei 'dpi|xft|font' || true
  echo

  echo "## XFCE display settings"
  xfconf-query --channel displays --list --verbose || true
  echo

  echo "## XFCE xsettings"
  xfconf-query --channel xsettings --list --verbose | grep -Ei 'dpi|font|scale|hint|rgba|antialias' || true
  echo

  echo "## GTK scaling environment"
  env | grep -Ei 'GDK_SCALE|GDK_DPI_SCALE|QT_SCALE|QT_AUTO|QT_SCREEN|XFT_DPI|ELM_SCALE' || true
  echo

  echo "## fontconfig DPI references"
  grep -RInE 'dpi|pixelsize|antialias|hinting|hintstyle|rgba' \
    "${HOME}/.config/fontconfig" \
    "${HOME}/.fonts.conf" \
    /etc/fonts/conf.d \
    /etc/fonts/local.conf 2>/dev/null || true
  echo

  echo "## Chrome / Chromium desktop flags"
  grep -RInE 'force-device-scale-factor|high-dpi|ozone|enable-features|disable-features' \
    "${HOME}/.local/share/applications" \
    /usr/share/applications 2>/dev/null || true
  echo

  echo "## autostart scaling commands"
  grep -RInE 'xrandr|xrdb|xft|dpi|scale|font|display' \
    "${HOME}/.config/autostart" \
    "${HOME}/.config/xfce4" \
    "${HOME}/.xprofile" \
    "${HOME}/.xinitrc" \
    "${HOME}/.Xresources" \
    "${HOME}/.bashrc" \
    "${HOME}/.profile" 2>/dev/null || true
}

main() {
  if [[ "$#" -eq 0 ]]; then
    show_help
    exit 1
  fi

  case "${1}" in
  --check)
    run_check
    ;;
  --help)
    show_help
    ;;
  *)
    echo "Unknown option: ${1}" >&2
    show_help
    exit 1
    ;;
  esac
}

main "$@"
