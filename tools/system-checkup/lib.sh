#!/bin/bash
#
# Shared helpers for system-checkup check files in checks.d/.
#
# Source this file from a check; do not execute it. Every helper prints one
# short result line on stdout and returns 0 (pass) or 1 (fail), so a check can
# end with `check_xyz ...; exit "${?}"` or just call the helper as its last
# command.

# Seconds a filesystem probe may take before the mount counts as hung. A dead
# FUSE mount can block `ls` forever; the timeout turns that into a failure.
SYSTEM_CHECKUP_PROBE_TIMEOUT="${SYSTEM_CHECKUP_PROBE_TIMEOUT:-20}"

# Check that a path is a mountpoint and that its root folder answers a listing.
#
# Usage: check_mount_responds <path> [<expected fstype>]
#
# The fstype is compared with the FSTYPE column of findmnt (for example
# `ext4` or `fuse.google-drive-ocamlfuse`). Omit it to accept any type.
check_mount_responds() {
  local path="${1}"
  local expected_type="${2:-}"
  local actual_type
  local error
  local rc

  # Read the mount table instead of stat-ing the path first: a broken FUSE
  # mount fails every stat ("Transport endpoint is not connected" and
  # similar), and would otherwise look like a missing folder.
  if ! findmnt -n --mountpoint "${path}" >/dev/null 2>&1; then
    if [[ -d "${path}" ]]; then
      printf '%s is not mounted\n' "${path}"
    else
      printf '%s is not mounted (the folder does not exist)\n' "${path}"
    fi
    return 1
  fi

  error="$(timeout "${SYSTEM_CHECKUP_PROBE_TIMEOUT}" stat -- "${path}" 2>&1 >/dev/null)"
  rc="${?}"
  if [[ "${rc}" -eq 124 ]]; then
    printf '%s is mounted but hung for more than %ss\n' "${path}" "${SYSTEM_CHECKUP_PROBE_TIMEOUT}"
    return 1
  fi
  if [[ "${rc}" -ne 0 ]]; then
    printf '%s is mounted but does not respond: %s\n' "${path}" "${error##*: }"
    return 1
  fi

  if [[ -n "${expected_type}" ]]; then
    actual_type="$(findmnt -n -o FSTYPE --mountpoint "${path}" 2>/dev/null)"
    if [[ "${actual_type}" != "${expected_type}" ]]; then
      printf '%s is mounted as "%s", expected "%s"\n' "${path}" "${actual_type}" "${expected_type}"
      return 1
    fi
  fi

  timeout "${SYSTEM_CHECKUP_PROBE_TIMEOUT}" ls -A -- "${path}" >/dev/null 2>&1
  rc="${?}"
  if [[ "${rc}" -eq 124 ]]; then
    printf '%s is mounted but listing the root folder hung for more than %ss\n' "${path}" "${SYSTEM_CHECKUP_PROBE_TIMEOUT}"
    return 1
  fi
  if [[ "${rc}" -ne 0 ]]; then
    printf '%s is mounted but the root folder cannot be listed (exit %s)\n' "${path}" "${rc}"
    return 1
  fi

  printf '%s is mounted and responds\n' "${path}"
  return 0
}

# Check a google-drive-ocamlfuse account: mounted at ~/GoogleDrive/<label>
# (the layout of configs/session/storage/gdrive-mounts.sh) and responsive.
#
# Usage: check_gdrive_label <label>
check_gdrive_label() {
  local label="${1}"
  local mountpoint="${HOME}/GoogleDrive/${label}"

  if ! check_mount_responds "${mountpoint}" "fuse.google-drive-ocamlfuse"; then
    printf 'Fix: ~/.dotfiles/configs/session/storage/gdrive-mounts.sh --label %s --verbose (it clears a stale mount; add --reauth if the sign-in expired)\n' "${label}"
    return 1
  fi
  return 0
}
