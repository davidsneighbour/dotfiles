#!/bin/bash
# shellcheck shell=bash

# dnb-synchhome.bash
#
# Synchronise selected home folders between gargulus and locutus.
#
# Public commands:
#   sync-home in <folder>
#   sync-home out <folder>
#   sync-home-in <folder>
#   sync-home-out <folder>
#
# Compatibility aliases:
#   synch_home
#   synch_home_in
#   synch_home_out
#
# Direction semantics:
#   in
#     Sync from the other machine to the current machine.
#
#   out
#     Sync from the current machine to the other machine.
#
# Host mapping:
#   gargulus -> patrick@192.168.1.201
#   locutus  -> patrick@192.168.1.202
#
# Examples:
#   sync-home out github.com/davidsneighbour
#   sync-home in Downloads
#   sync-home-out Downloads
#   sync-home-in Downloads
#
# Notes:
#   - Folder contents are synced, not the parent folder itself.
#   - Files missing on the source are deleted on the target.
#   - Numeric user and group IDs are preserved.
#   - ACLs, xattrs and hardlinks are preserved where supported.
#   - This file is intended for interactive Bash loading and therefore does
#     not set global shell options such as set -euo pipefail.

# Print usage for sync-home.
#
# Parameters:
#   None.
#
# Output:
#   Prints help text to stdout.
#
# Returns:
#   0.
#
# Example:
#   dnb_sync_home_help
dnb_sync_home_help() {
  cat <<EOF_HELP
Usage:
  sync-home in <folder>
  sync-home out <folder>
  sync-home --help

Examples:
  sync-home out github.com/davidsneighbour
  sync-home in Downloads
  sync-home-out Downloads
  sync-home-in Downloads

Directions:
  in    Sync from the other machine to this machine
  out   Sync from this machine to the other machine

Known hosts:
  gargulus -> locutus
  locutus  -> gargulus

Behaviour:
  - Syncs folder contents, not the parent folder itself.
  - Deletes files on the target that no longer exist on the source.
  - Preserves numeric user and group IDs.
  - Preserves hardlinks, ACLs and xattrs where supported.

Requirements:
  - rsync installed locally and remotely.
  - SSH access between both machines.
  - Compatible UID/GID values on both machines.
EOF_HELP
}

# Resolve the opposite host for the current machine.
#
# Parameters:
#   None.
#
# Output:
#   Prints the remote hostname or IP address to stdout.
#
# Returns:
#   0 when the current host is known.
#   1 when the current host cannot be detected.
#   2 when the current host is unsupported.
#
# Example:
#   remote_host="$(dnb_sync_home_remote_host)"
dnb_sync_home_remote_host() {
  local current_host=""

  current_host="$(hostname -s 2>/dev/null)" || {
    printf 'Error: could not detect current hostname.\n' >&2
    return 1
  }

  current_host="${current_host,,}"

  case "${current_host}" in
    gargulus)
      printf '%s\n' "192.168.1.201"
      ;;

    locutus)
      printf '%s\n' "192.168.1.202"
      ;;

    *)
      printf 'Error: unknown current host: %s\n' "${current_host}" >&2
      printf 'Expected "gargulus" or "locutus".\n' >&2
      return 2
      ;;
  esac
}

# Normalise a user-supplied folder path into a HOME-relative path.
#
# Parameters:
#   $1 - Folder path. May be "Downloads", "~/Downloads", or "/home/patrick/Downloads".
#
# Output:
#   Prints a path relative to HOME without a leading slash.
#
# Returns:
#   0 when the path can be normalised.
#   1 when no folder was supplied.
#   2 when an absolute path outside HOME was supplied.
#
# Examples:
#   dnb_sync_home_normalise_folder "Downloads"
#   dnb_sync_home_normalise_folder "~/Downloads"
#   dnb_sync_home_normalise_folder "/home/patrick/Downloads"
dnb_sync_home_normalise_folder() {
  local folder="${1:-}"

  if [ -z "${folder}" ]; then
    printf 'Error: missing folder.\n' >&2
    return 1
  fi

  folder="${folder/#\~/${HOME}}"

  case "${folder}" in
    "${HOME}"/*)
      folder="${folder#"${HOME}/"}"
      ;;

    /*)
      printf 'Error: folder must be inside HOME: %s\n' "${folder}" >&2
      return 2
      ;;
  esac

  folder="${folder#/}"
  folder="${folder%/}"

  if [ -z "${folder}" ]; then
    printf 'Error: refusing to sync the entire HOME directory.\n' >&2
    return 2
  fi

  printf '%s\n' "${folder}"
}

# Synchronise a folder between the current machine and the opposite home machine.
#
# Parameters:
#   $1 - Direction. Must be "in" or "out".
#   $2 - Folder path relative to HOME, or a HOME-based absolute path.
#
# Options:
#   -h, --help
#     Show usage information.
#
# Behaviour:
#   - "out" syncs from the current machine to the other machine.
#   - "in" syncs from the other machine to the current machine.
#   - Uses rsync archive mode plus hardlinks, ACLs, xattrs, verbose output,
#     numeric IDs and delete-on-target behaviour.
#   - Creates the target directory before syncing.
#
# Returns:
#   0 when the sync completed successfully.
#   1 or higher when validation or rsync failed.
#
# Examples:
#   sync-home out Downloads
#   sync-home in github.com/davidsneighbour
sync-home() {
  local remote_user="patrick"
  local remote_host=""
  local direction="${1:-}"
  local folder_input="${2:-}"
  local folder=""
  local local_path=""
  local remote_path=""

  if [ "${direction}" = "--help" ] || [ "${direction}" = "-h" ] || [ "$#" -lt 2 ]; then
    dnb_sync_home_help
    return 0
  fi

  case "${direction}" in
    in | out)
      ;;

    *)
      printf 'Error: unknown direction: %s\n' "${direction}" >&2
      printf 'Use "sync-home --help" for usage.\n' >&2
      return 1
      ;;
  esac

  remote_host="$(dnb_sync_home_remote_host)" || {
    return $?
  }

  folder="$(dnb_sync_home_normalise_folder "${folder_input}")" || {
    return $?
  }

  local_path="${HOME}/${folder}"
  remote_path="~/${folder}"

  case "${direction}" in
    in)
      mkdir -p -- "${local_path}" || {
        printf 'Error: could not create local target folder: %s\n' "${local_path}" >&2
        return 1
      }

      rsync -aHAXv --numeric-ids --delete \
        "${remote_user}@${remote_host}:${remote_path}/" \
        "${local_path}/"
      ;;

    out)
      if [ ! -d "${local_path}" ]; then
        printf 'Error: local source folder does not exist: %s\n' "${local_path}" >&2
        return 1
      fi

      ssh "${remote_user}@${remote_host}" "mkdir -p -- ${remote_path}" || {
        printf 'Error: could not create remote target folder: %s@%s:%s\n' \
          "${remote_user}" \
          "${remote_host}" \
          "${remote_path}" >&2
        return 1
      }

      rsync -aHAXv --numeric-ids --delete \
        "${local_path}/" \
        "${remote_user}@${remote_host}:${remote_path}/"
      ;;
  esac
}

# Sync from the other machine to the current machine.
#
# Parameters:
#   $1 - Folder path relative to HOME, or a HOME-based absolute path.
#
# Options:
#   -h, --help
#     Show usage information.
#
# Example:
#   sync-home-in Downloads
sync-home-in() {
  if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ] || [ "$#" -lt 1 ]; then
    cat <<EOF_HELP
Usage:
  ${FUNCNAME[0]} <folder>

Example:
  ${FUNCNAME[0]} Downloads

Syncs from the other machine to this machine.
EOF_HELP
    return 0
  fi

  sync-home in "${1}"
}

# Sync from the current machine to the other machine.
#
# Parameters:
#   $1 - Folder path relative to HOME, or a HOME-based absolute path.
#
# Options:
#   -h, --help
#     Show usage information.
#
# Example:
#   sync-home-out Downloads
sync-home-out() {
  if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ] || [ "$#" -lt 1 ]; then
    cat <<EOF_HELP
Usage:
  ${FUNCNAME[0]} <folder>

Example:
  ${FUNCNAME[0]} Downloads

Syncs from this machine to the other machine.
EOF_HELP
    return 0
  fi

  sync-home out "${1}"
}

# Compatibility wrappers for the requested synch_home naming.
synch_home() {
  sync-home "$@"
}

synch_home_in() {
  sync-home-in "$@"
}

synch_home_out() {
  sync-home-out "$@"
}
