# shellcheck shell=bash

# dnb_auto_source
#
# Source one or more files, glob patterns, or all matching readable regular
# files inside one or more directories. This function is source-safe and
# performs no work unless called.
#
# Parameters:
#   paths...       One or more file paths, directory paths, or quoted glob
#                 strings.
#   path pattern   When exactly two arguments are given and the first argument
#                 is a directory, the second argument may define the file glob
#                 to source from that directory.
#
# Behaviour:
#   - Readable regular files are sourced directly.
#   - Readable regular files inside directories are sourced in lexical order.
#   - Quoted glob strings source each matching readable regular file in lexical
#     order.
#   - Directory patterns only match files directly inside that directory.
#   - Missing, unreadable, or unmatched paths are skipped silently.
#
# Examples:
#   dnb_auto_source "${HOME}/.bash_completion.d"
#   dnb_auto_source "${BASHRC_PATH}/_lib/00-core"
#   dnb_auto_source "${BASHRC_PATH}/_lib/00-core/*.bash"
#   dnb_auto_source "${BASHRC_PATH}/_lib/00-core" "*.bash"
#
# Requirements:
#   - bash

dnb_auto_source() {
  local item=""

  if [[ ${#} -eq 2 && -d "${1}" && ! -e "${2}" ]]; then
    dnb_auto_source_matching_files "${1}" "${2}"
    return
  fi

  for item in "$@"; do
    if dnb_auto_source_contains_glob "${item}"; then
      dnb_auto_source_glob "${item}"
      continue
    fi

    if [[ -d "${item}" ]]; then
      dnb_auto_source_matching_files "${item}" "*"
      continue
    fi

    dnb_auto_source_readable_file "${item}"
  done
}

dnb_auto_source_contains_glob() {
  local value="${1}"

  [[ "${value}" == *'*'* || "${value}" == *'?'* || "${value}" == *'['* ]]
}

dnb_auto_source_matching_files() {
  local directory="${1%/}"
  local pattern="${2}"
  local file=""
  local nullglob_was_enabled="false"
  local -a files=()

  [[ -d "${directory}" ]] || return 0

  if shopt -q nullglob; then
    nullglob_was_enabled="true"
  fi

  shopt -s nullglob

  # The unquoted pattern is intentional: this function receives a glob pattern
  # that defines which files should be sourced from the already-validated
  # directory.
  # shellcheck disable=SC2206
  files=("${directory}"/${pattern})

  if [[ "${nullglob_was_enabled}" != "true" ]]; then
    shopt -u nullglob
  fi

  for file in "${files[@]}"; do
    dnb_auto_source_readable_file "${file}"
  done
}

dnb_auto_source_glob() {
  local glob_path="${1}"
  local directory=""
  local pattern=""

  if [[ "${glob_path}" == */* ]]; then
    directory="${glob_path%/*}"
    pattern="${glob_path##*/}"
  else
    directory="."
    pattern="${glob_path}"
  fi

  if [[ -z "${directory}" ]]; then
    directory="/"
  fi

  dnb_auto_source_matching_files "${directory}" "${pattern}"
}

dnb_auto_source_readable_file() {
  local file="${1}"

  if [[ -f "${file}" && -r "${file}" ]]; then
    # shellcheck source=/dev/null
    source "${file}"
  fi
}
