#!/bin/bash

set -euo pipefail

##
# Show help for this script.
#
# Usage:
#   $(basename "$0") [--source-dir PATH] [--sizes LIST] [--verbose] [--help]
#
# Behaviour:
#   - Reads SVG icons from `scalable/apps`.
#   - Generates PNG renditions for configured fixed sizes.
#   - Writes output into `<size>x<size>/apps/`.
##
show_help() {
  cat <<EOF
Usage:
  $(basename "$0") [--source-dir PATH] [--sizes LIST] [--verbose] [--help]

Options:
  --source-dir PATH   Theme source directory.
                      Default: ${HOME}/github.com/davidsneighbour/dotfiles/assets/icons/dnb
  --sizes LIST        Comma-separated sizes.
                      Default: 16,24,32,48,64
  --verbose           Print extra output.
  --help              Show this help.

Examples:
  $(basename "$0")
  $(basename "$0") --sizes 16,24,32,48,64,128
  $(basename "$0") --source-dir ${HOME}/github.com/davidsneighbour/dotfiles/assets/icons/dnb
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
# Validate theme source layout.
#
# Parameters:
#   None
##
validate_source() {
  if [[ ! -d "${source_dir}" ]]; then
    log_error "Source directory does not exist: ${source_dir}"
    exit 1
  fi

  if [[ ! -d "${source_dir}/scalable/apps" ]]; then
    log_error "Missing scalable apps directory: ${source_dir}/scalable/apps"
    exit 1
  fi
}

##
# Generate PNGs from all SVG files for all configured sizes.
#
# Parameters:
#   None
##
generate_icons() {
  local found_svg="false"
  local svg_file=""
  local base_name=""
  local size=""
  local output_dir=""
  local output_file=""

  shopt -s nullglob

  for svg_file in "${source_dir}"/scalable/apps/*.svg; do
    found_svg="true"
    base_name="$(basename "${svg_file}" .svg)"

    for size in "${sizes[@]}"; do
      output_dir="${source_dir}/${size}x${size}/apps"
      output_file="${output_dir}/${base_name}.png"

      mkdir -p "${output_dir}"

      log_verbose "Generating ${output_file} from ${svg_file}"
      rsvg-convert \
        --width "${size}" \
        --height "${size}" \
        --output "${output_file}" \
        "${svg_file}"
    done

    log_info "Generated PNG sizes for ${base_name}"
  done

  shopt -u nullglob

  if [[ "${found_svg}" != "true" ]]; then
    log_error "No SVG files found in ${source_dir}/scalable/apps"
    exit 1
  fi
}

source_dir="${HOME}/github.com/davidsneighbour/dotfiles/configs/system/icons/dnb"
sizes_csv="16,24,32,48,64,128,512"
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
    --sizes)
      shift
      if [[ "$#" -eq 0 ]]; then
        log_error "Missing value for --sizes"
        show_help
        exit 1
      fi
      sizes_csv="${1}"
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

IFS=',' read -r -a sizes <<< "${sizes_csv}"

require_command "mkdir"
require_command "rsvg-convert"

validate_source
generate_icons

log_info "PNG icon generation completed."