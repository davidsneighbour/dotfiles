#!/bin/bash

auto_source() {
  # Call with either a single directory path:
  #   auto_source "/path/to/completions"
  # Or a single file path:
  #   auto_source "/path/to/completions.sh"
  # Or multiple paths:
  #   auto_source "/path/to/one" "/path/to/two"
  # Or pass an array:
  #   auto_source "${ARRAY_OF_PATHS[@]}"
  #
  for ITEM in "$@"; do
    if [ -d "${ITEM}" ]; then
      for FILE in "${ITEM}"/*; do
        # shellcheck source=/dev/null
        [ -r "${FILE}" ] && [ -f "${FILE}" ] && source "${FILE}"
      done
    elif [ -r "${ITEM}" ] && [ -f "${ITEM}" ]; then
      # shellcheck source=/dev/null
      source "${ITEM}"
    fi
  done
}
