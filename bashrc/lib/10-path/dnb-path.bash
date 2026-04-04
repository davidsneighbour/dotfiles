# shellcheck shell=bash

# dnb_path_contains
#
# Check whether a directory is already present in PATH.
#
# Parameters:
#   --dir <path>  Directory to check.
#
# Examples:
#   dnb_path_contains --dir "${HOME}/.local/bin"
#
# Requirements:
#   * bash

dnb_path_contains() {
  local dir=''
  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
      --help)
        cat <<EOF2
${FUNCNAME[0]} - check whether a directory is already present in PATH

Usage:
  ${FUNCNAME[0]} --dir <path>
EOF2
        return 0
        ;;
      --dir)
        shift
        dir="${1:-}"
        ;;
      *)
        printf 'Unknown option: %s\n' "${1}" >&2
        return 1
        ;;
    esac
    shift
  done

  [[ -n "${dir}" ]] || return 1
  [[ ":${PATH}:" == *":${dir}:"* ]]
}

# dnb_path_add_if_missing
#
# Add a directory to PATH only when it is not already present.
#
# Parameters:
#   --dir <path>       Directory to add.
#   --prepend          Add to the beginning of PATH. Default.
#   --append           Add to the end of PATH.
#   --verbose          Print a message when the directory is already present.
#
# Behaviour:
#   * Returns 0 when PATH already contains the directory or when it was added.
#   * Returns 1 when the directory argument is missing or does not exist.
#
# Examples:
#   dnb_path_add_if_missing --dir "${HOME}/.local/bin"
#   dnb_path_add_if_missing --dir "/opt/bin" --append --verbose
#
# Requirements:
#   * bash

dnb_path_add_if_missing() {
  local dir=''
  local mode='prepend'
  local verbose='false'

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
      --help)
        cat <<EOF2
${FUNCNAME[0]} - add a directory to PATH only when missing

Usage:
  ${FUNCNAME[0]} --dir <path> [--prepend|--append] [--verbose]
EOF2
        return 0
        ;;
      --dir)
        shift
        dir="${1:-}"
        ;;
      --prepend)
        mode='prepend'
        ;;
      --append)
        mode='append'
        ;;
      --verbose)
        verbose='true'
        ;;
      *)
        printf 'Unknown option: %s\n' "${1}" >&2
        return 1
        ;;
    esac
    shift
  done

  if [[ -z "${dir}" || ! -d "${dir}" ]]; then
    dnb_error "Path does not exist or was not provided: ${dir}"
    return 1
  fi

  if dnb_path_contains --dir "${dir}"; then
    if [[ "${verbose}" == 'true' || "${DNB_VERBOSE:-0}" == '1' || "${DNB_VERBOSE:-false}" == 'true' ]]; then
      dnb_log info "PATH already contains ${dir}"
    fi
    return 0
  fi

  if [[ "${mode}" == 'append' ]]; then
    PATH="${PATH:+${PATH}:}${dir}"
  else
    PATH="${dir}${PATH:+:${PATH}}"
  fi
  export PATH
  dnb_log success "Added ${dir} to PATH (${mode})"
  return 0
}

# dnb_path_sanitise
#
# Remove duplicate and non-existing directories from PATH while preserving the
# first valid occurrence.
#
# Parameters:
#   none
#
# Examples:
#   dnb_path_sanitise
#
# Requirements:
#   * bash

dnb_path_sanitise() {
  local old_path="${PATH:-}"
  local entry=''
  local -a parts=()
  local -a clean=()
  local seen=':'

  IFS=':' read -r -a parts <<< "${old_path}"
  for entry in "${parts[@]}"; do
    [[ -n "${entry}" ]] || continue
    [[ -d "${entry}" ]] || continue
    [[ "${seen}" == *":${entry}:"* ]] && continue
    clean+=("${entry}")
    seen+="${entry}:"
  done

  PATH="$(IFS=':'; printf '%s' "${clean[*]}")"
  export PATH
  dnb_log success "PATH sanitised"
}
