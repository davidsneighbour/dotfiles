#!/bin/bash

set -euo pipefail

##
# Show help for this script.
#
# Usage:
#   $(basename "$0") [--source-dir PATH] [--target-dir PATH] [--copy] [--force] [--verbose] [--help]
#
# Behaviour:
#   - Validates the source theme directory and its index.theme file.
#   - Installs the DNB icon theme into the user's local icon directory.
#   - Links only the `dnb` theme directory by default.
#   - Optionally copies instead of symlinking.
#   - Refreshes icon and desktop caches when helper tools are available.
##
show_help() {
  cat <<EOF
Usage:
  $(basename "$0") [--source-dir PATH] [--target-dir PATH] [--copy] [--force] [--verbose] [--help]

Options:
  --source-dir PATH   Source theme directory.
                      Default: ${HOME}/github.com/davidsneighbour/dotfiles/configs/system/icons/dnb
  --target-dir PATH   Target theme directory.
                      Default: ${HOME}/.local/share/icons/dnb
  --copy              Copy files instead of creating a symlink.
  --force             Replace an existing target.
  --verbose           Print extra output.
  --help              Show this help.

Examples:
  $(basename "$0")
  $(basename "$0") --verbose
  $(basename "$0") --force
  $(basename "$0") --copy --force
EOF
}

##
# Print an informational message.
#
# Parameters:
#   $1 - Message text
##
log_info() {
  local message="${1:-}"
  printf 'INFO %s\n' "${message}"
}

##
# Print a verbose message if verbose mode is enabled.
#
# Parameters:
#   $1 - Message text
##
log_verbose() {
  local message="${1:-}"
  if [[ "${verbose}" == "true" ]]; then
    printf 'VERBOSE %s\n' "${message}"
  fi
}

##
# Print an error message to stderr.
#
# Parameters:
#   $1 - Message text
##
log_error() {
  local message="${1:-}"
  printf 'ERROR %s\n' "${message}" >&2
}

##
# Ensure a required command exists.
#
# Parameters:
#   $1 - Command name
##
require_command() {
  local command_name="${1:-}"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log_error "Required command not found: ${command_name}"
    exit 1
  fi
}

##
# Validate the source theme directory.
#
# Parameters:
#   None
##
validate_source() {
  if [[ ! -d "${source_dir}" ]]; then
    log_error "Source directory does not exist: ${source_dir}"
    show_help
    exit 1
  fi

  if [[ ! -f "${source_dir}/index.theme" ]]; then
    log_error "Missing index.theme in source directory: ${source_dir}"
    exit 1
  fi
}

##
# Install the theme by symlink or copy.
#
# Parameters:
#   None
##
install_theme() {
  local parent_dir
  parent_dir="$(dirname "${target_dir}")"

  mkdir -p "${parent_dir}"

  if [[ -e "${target_dir}" || -L "${target_dir}" ]]; then
    if [[ "${force}" != "true" ]]; then
      log_error "Target already exists: ${target_dir}"
      log_error "Use --force to replace it."
      exit 1
    fi

    log_verbose "Removing existing target: ${target_dir}"
    rm -rf "${target_dir}"
  fi

  if [[ "${copy_mode}" == "true" ]]; then
    log_info "Copying theme directory to ${target_dir}"
    cp -a "${source_dir}" "${target_dir}"
  else
    log_info "Creating symlink ${target_dir} -> ${source_dir}"
    ln -s "${source_dir}" "${target_dir}"
  fi
}

##
# Refresh icon and desktop caches when tools are available.
#
# Parameters:
#   None
##
refresh_caches() {
  local icon_root
  icon_root="$(dirname "${target_dir}")"

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    if [[ -d "${target_dir}" ]]; then
      log_verbose "Refreshing icon cache for ${target_dir}"
      gtk-update-icon-cache --force "${target_dir}" >/dev/null 2>&1 || true
    fi

    if [[ -d "${icon_root}/hicolor" ]]; then
      log_verbose "Refreshing icon cache for ${icon_root}/hicolor"
      gtk-update-icon-cache --force "${icon_root}/hicolor" >/dev/null 2>&1 || true
    fi
  else
    log_verbose "gtk-update-icon-cache not found, skipping icon cache refresh"
  fi

  if command -v update-desktop-database >/dev/null 2>&1; then
    if [[ -d "${HOME}/.local/share/applications" ]]; then
      log_verbose "Refreshing desktop database in ${HOME}/.local/share/applications"
      update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
    fi
  else
    log_verbose "update-desktop-database not found, skipping desktop database refresh"
  fi
}

source_dir="${HOME}/github.com/davidsneighbour/dotfiles/configs/system/icons/dnb"
target_dir="${HOME}/.local/share/icons/dnb"
copy_mode="false"
force="false"
verbose="false"

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    --source-dir)
      shift
      if [[ "$#" -eq 0 ]]; then
        log_error "Missing value for --source-dir"
        show_help
        exit 1
      fi
      source_dir="${1}"
      ;;
    --target-dir)
      shift
      if [[ "$#" -eq 0 ]]; then
        log_error "Missing value for --target-dir"
        show_help
        exit 1
      fi
      target_dir="${1}"
      ;;
    --copy)
      copy_mode="true"
      ;;
    --force)
      force="true"
      ;;
    --verbose)
      verbose="true"
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
  shift
done

require_command "mkdir"
require_command "rm"
require_command "ln"
require_command "cp"

validate_source
install_theme
refresh_caches

log_info "Theme installed successfully."
log_info "Theme slug: dnb"
log_info "Theme name: DNB Icons"
log_info "Target path: ${target_dir}"