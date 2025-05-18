#!/bin/bash

create_local_desktop() {

  local DEFAULT_TEMP_DIR="${HOME}/.config/Local/local-tmp-folder"
  local DEFAULT_BINARY="/opt/Local/local"

  local TEMP_DIR="${DEFAULT_TEMP_DIR}"
  local LOCAL_BINARY="${DEFAULT_BINARY}"

  while [[ $# -gt 0 ]]; do
    case $1 in
    --tmpdir)
      TEMP_DIR="$2"
      shift 2
      ;;
    --binary)
      LOCAL_BINARY="$2"
      shift 2
      ;;
    --help)
      echo "Usage: create_local_desktop [--tmpdir <temp_dir>] [--binary <local_binary>]"
      return 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: create_local_desktop [--tmpdir <temp_dir>] [--binary <local_binary>]"
      return 1
      ;;
    esac
  done

  mkdir -p "${TEMP_DIR}"

  # check if LOCAL_BINARY exists and is executable
  if [[ ! -x "${LOCAL_BINARY}" ]]; then
    echo "Error: ${LOCAL_BINARY} does not exist or is not executable."
    return 1
  fi

  local DESKTOP_FILE_CONTENT="[Desktop Entry]
Name=Local
Exec=bash -c 'export TMPDIR=\"${TEMP_DIR}\"; ${LOCAL_BINARY} %U'
Terminal=false
Type=Application
Icon=local
StartupWMClass=Local
Comment=Create local WordPress sites with ease.
MimeType=x-scheme-handler/flywheel-local;
Categories=Development;"

  local DESKTOP_FILE_PATH="${HOME}/.local/share/applications/local.desktop"
  echo "${DESKTOP_FILE_CONTENT}" >"${DESKTOP_FILE_PATH}"

  echo "Desktop entry created at ${DESKTOP_FILE_PATH}"
}


create_local_desktop "$@"
