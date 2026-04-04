# shellcheck shell=bash

# dnb_check_requirements
#
# Verify that required commands exist in PATH.
#
# Parameters:
#   commands...  One or more command names.
#
# Behaviour:
#   - Returns 0 when all commands exist or when no commands were provided.
#   - Returns 1 when one or more commands are missing.
#   - Prints all missing command names to stderr.
#   - Never exits the caller.
#
# Examples:
#   dnb_check_requirements git curl sed
#   dnb_check_requirements "${REQUIRED_TOOLS[@]}" || return 1
#
# Requirements:
#   - bash

dnb_check_requirements() {
  local missing=0
  local tool=""

  if [[ "$#" -eq 0 ]]; then
    return 0
  fi

  for tool in "$@"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      printf 'Missing required command: %s\n' "${tool}" >&2
      missing=1
    fi
  done

  return "${missing}"
}
