# shellcheck shell=bash

# dnb_path_trim
#
# Trim leading and trailing horizontal whitespace from a path-like value.
#
# Usage:
#   dnb_path_trim <value>

dnb_path_trim() {
  local value="${1:-}"

  if [[ "${1:-}" == '--help' ]]; then
    cat <<EOF_HELP
${FUNCNAME[0]} - trim leading and trailing path whitespace

Usage:
  ${FUNCNAME[0]} <value>
EOF_HELP
    return 0
  fi

  value="${value#"${value%%[!$' \t']*}"}"
  value="${value%"${value##*[!$' \t']}"}"
  printf '%s' "${value}"
}

# dnb_path_expand
#
# Expand the user-facing path syntax used by helper command config files.
#
# Supported syntax:
#   ~ and ~/ at the start of a path
#   $HOME anywhere in the path
#   other $VARIABLE references when envsubst is available
#
# Usage:
#   dnb_path_expand <path>

dnb_path_expand() {
  local value="${1:-}"

  if [[ "${1:-}" == '--help' ]]; then
    cat <<EOF_HELP
${FUNCNAME[0]} - expand configured path values

Usage:
  ${FUNCNAME[0]} <path>

Expands:
  ~
  ~/<path>
  \$HOME
  other \$VARIABLE references when envsubst is available
EOF_HELP
    return 0
  fi

  value="$(dnb_path_trim "${value}")"

  if [[ "${value}" == '~' ]]; then
    value="${HOME}"
  elif [[ "${value}" == ~/* ]]; then
    value="${HOME}/${value#~/}"
  fi

  value="${value//\$HOME/${HOME}}"

  if command -v envsubst >/dev/null 2>&1; then
    value="$(printf '%s' "${value}" | envsubst)"
  fi

  printf '%s' "${value}"
}

# dnb_path_has_glob
#
# Return success when a path contains Bash glob syntax.
#
# Usage:
#   dnb_path_has_glob <path>

dnb_path_has_glob() {
  local value="${1:-}"

  if [[ "${1:-}" == '--help' ]]; then
    cat <<EOF_HELP
${FUNCNAME[0]} - test whether a path contains glob syntax

Usage:
  ${FUNCNAME[0]} <path>

Recognised syntax:
  *
  ?
  [...]
  ** when globstar is enabled by the caller/resolver
EOF_HELP
    return 0
  fi

  case "${value}" in
    *'*'* | *'?'* | *'['*']'*) return 0 ;;
    *) return 1 ;;
  esac
}

# dnb_path_resolve_pattern
#
# Resolve a single expanded path or glob pattern and print matching paths.
# Returns 0 when at least one path exists/matches, otherwise returns 1.
#
# Usage:
#   dnb_path_resolve_pattern <path-or-glob>

dnb_path_resolve_pattern() {
  local pattern="${1:-}"
  local matched_path=''
  local found_match='false'

  if [[ "${1:-}" == '--help' ]]; then
    cat <<EOF_HELP
${FUNCNAME[0]} - resolve an expanded path or Bash glob pattern

Usage:
  ${FUNCNAME[0]} <path-or-glob>

Glob support:
  *       path segment wildcard
  ?       single-character wildcard
  [...]   character set/range wildcard
  **      recursive wildcard
EOF_HELP
    return 0
  fi

  if [[ -z "${pattern}" ]]; then
    return 1
  fi

  if dnb_path_has_glob "${pattern}"; then
    while IFS= read -r matched_path; do
      if [[ -n "${matched_path}" ]]; then
        printf '%s\n' "${matched_path}"
        found_match='true'
      fi
    done < <(
      shopt -s globstar nullglob dotglob
      compgen -G "${pattern}" || true
    )

    [[ "${found_match}" == 'true' ]]
    return "${?}"
  fi

  if [[ -e "${pattern}" ]]; then
    printf '%s\n' "${pattern}"
    return 0
  fi

  return 1
}
