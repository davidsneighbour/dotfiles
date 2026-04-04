# shellcheck shell=bash

# dnb_auto_source
#
# Source one or more files or all readable regular files inside one or more
# directories. This function is source-safe and performs no work unless called.
#
# Parameters:
#   paths...  One or more file or directory paths.
#
# Behaviour:
#   - Readable regular files are sourced directly.
#   - Readable regular files inside directories are sourced in lexical order.
#   - Missing or unreadable paths are skipped silently.
#
# Examples:
#   dnb_auto_source "${HOME}/.bash_completion.d"
#   dnb_auto_source "${BASHRC_PATH}/_lib/00-core"
#
# Requirements:
#   - bash

dnb_auto_source() {
  local item=""
  local file=""

  for item in "$@"; do
    if [[ -d "${item}" ]]; then
      for file in "${item}"/*; do
        [[ -f "${file}" && -r "${file}" ]] || continue
        # shellcheck source=/dev/null
        source "${file}"
      done
      continue
    fi

    if [[ -f "${item}" && -r "${item}" ]]; then
      # shellcheck source=/dev/null
      source "${item}"
    fi
  done
}
