#!/bin/bash

set -euo pipefail

show_help() {
  local script_name
  script_name="$(basename "$0")"

  cat <<HELP
Usage:
  ${script_name} --apply
  ${script_name} --check
  ${script_name} --help

Fix XFCE/Xft font rendering settings for low-PPI monitors.

Options:
  --apply   Apply recommended XFCE and Xft font rendering settings.
  --check   Print current XFCE and Xresources font rendering settings.
  --help    Show this help output.

Behaviour:
  - Enables Xft antialiasing.
  - Enables hinting.
  - Uses hintslight instead of hintfull.
  - Sets RGB subpixel rendering.
  - Leaves DPI automatic via /Xft/DPI -1.
  - Removes a stale Xft.antialias entry from the current xrdb state before merging the corrected value.

Examples:
  ${script_name} --check
  ${script_name} --apply
HELP
}

require_display_session() {
  if [[ -z "${DISPLAY:-}" ]]; then
    echo "Error: DISPLAY is not set. This script must run inside an X11 desktop session." >&2
    exit 1
  fi

  if ! command -v xfconf-query >/dev/null 2>&1; then
    echo "Error: xfconf-query is not installed or not available in PATH." >&2
    exit 1
  fi

  if ! command -v xrdb >/dev/null 2>&1; then
    echo "Error: xrdb is not installed or not available in PATH." >&2
    exit 1
  fi
}

check_settings() {
  require_display_session

  echo "## Xresources Xft settings"
  xrdb -query | grep -Ei 'dpi|xft' || true
  echo

  echo "## XFCE xsettings"
  xfconf-query --channel xsettings --list --verbose | grep -Ei 'dpi|font|hint|rgba|antialias' || true
}

apply_xfce_settings() {
  require_display_session

  xfconf-query --channel xsettings --property /Xft/Antialias --set 1
  xfconf-query --channel xsettings --property /Xft/Hinting --set 1
  xfconf-query --channel xsettings --property /Xft/HintStyle --set hintslight
  xfconf-query --channel xsettings --property /Xft/RGBA --set rgb
  xfconf-query --channel xsettings --property /Xft/DPI --set -1

  xfconf-query --channel xsettings --property /Gtk/FontName --set "Noto Sans 9"
  xfconf-query --channel xsettings --property /Gtk/MonospaceFontName --set "JetBrains Mono 10"
}

apply_xresources_settings() {
  require_display_session

  local xrdb_tmp
  xrdb_tmp="$(mktemp --tmpdir="${HOME}/tmp" fix-xfce-font-rendering.XXXXXXXXXX 2>/dev/null || mktemp)"

  {
    xrdb -query | grep -vE '^Xft\.(antialias|hinting|hintstyle|rgba|lcdfilter):' || true
    printf '%s\n' 'Xft.antialias: 1'
    printf '%s\n' 'Xft.hinting: 1'
    printf '%s\n' 'Xft.hintstyle: hintslight'
    printf '%s\n' 'Xft.rgba: rgb'
    printf '%s\n' 'Xft.lcdfilter: lcddefault'
  } >"${xrdb_tmp}"

  xrdb -merge "${xrdb_tmp}"
  rm -f "${xrdb_tmp}"
}

apply_settings() {
  apply_xfce_settings
  apply_xresources_settings

  echo "Applied XFCE/Xft font rendering settings."
  echo
  check_settings
}

main() {
  if [[ "$#" -eq 0 ]]; then
    show_help
    exit 1
  fi

  case "${1}" in
  --apply)
    apply_settings
    ;;
  --check)
    check_settings
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
