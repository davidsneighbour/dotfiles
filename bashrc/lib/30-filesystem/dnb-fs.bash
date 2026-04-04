# shellcheck shell=bash

# dnb_create_directory
#
# Ensure that a directory exists.
#
# Parameters:
#   path  Directory path to create.
#
# Behaviour:
#   * Returns 0 when the directory already exists or was created.
#   * Returns 1 when the path is empty or creation fails.
#
# Examples:
#   dnb_create_directory "${HOME}/.logs"
#
# Requirements:
#   * bash
#   * mkdir

dnb_create_directory() {
  local dir_path="${1:-}"

  if [[ -z "${dir_path}" ]]; then
    dnb_error "dnb_create_directory called with empty path"
    return 1
  fi

  if [[ -d "${dir_path}" ]]; then
    dnb_log info "Directory already exists: ${dir_path}"
    return 0
  fi

  if mkdir -p "${dir_path}"; then
    dnb_log success "Created directory: ${dir_path}"
    return 0
  fi

  dnb_error "Failed to create directory: ${dir_path}"
  return 1
}

# dnb_execute_lines
#
# Read a file line by line and pass each line as a single argument to a callback
# function. This is the safe replacement for the old eval-based execute helper.
#
# Parameters:
#   file       Input file.
#   callback   Bash function to call for each line.
#
# Behaviour:
#   * Returns 1 when the file or callback is missing.
#   * Stops on the first callback failure and returns that status.
#
# Examples:
#   my_handler() { printf 'Line: %s\n' "${1}"; }
#   dnb_execute_lines ./items.txt my_handler
#
# Requirements:
#   * bash

dnb_execute_lines() {
  local file="${1:-}"
  local callback="${2:-}"
  local line=''
  local status=0

  if [[ -z "${file}" || -z "${callback}" ]]; then
    printf 'Usage: %s <file> <callback>\n' "${FUNCNAME[0]}" >&2
    return 1
  fi

  if [[ ! -f "${file}" ]]; then
    printf 'File not found: %s\n' "${file}" >&2
    return 1
  fi

  if ! declare -F "${callback}" >/dev/null 2>&1; then
    printf 'Callback function not found: %s\n' "${callback}" >&2
    return 1
  fi

  while IFS= read -r line; do
    "${callback}" "${line}"
    status=$?
    if [[ "${status}" -ne 0 ]]; then
      return "${status}"
    fi
  done < "${file}"

  return 0
}
