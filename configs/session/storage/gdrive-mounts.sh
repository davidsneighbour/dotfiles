#!/usr/bin/env bash

set -u

mount_google_drive() {

  local label="$1"
  local mountpoint="$2"

  mkdir -p "${mountpoint}"

  if mountpoint -q "${mountpoint}"; then
    return 0
  fi

  local logfile="${HOME}/.logs/google-drive-ocamlfuse-${label}.log"

  google-drive-ocamlfuse \
    -label "${label}" \
    "${mountpoint}" \
    >>"${logfile}" 2>&1 &

}

mount_google_drive "pkollitsch" "${HOME}/GoogleDrive/pkollitsch"
mount_google_drive "davidsneighbour" "${HOME}/GoogleDrive/davidsneighbour"
