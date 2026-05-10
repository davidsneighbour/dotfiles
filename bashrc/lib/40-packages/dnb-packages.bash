# shellcheck shell=bash

# dnb_package_list_sections
#
# Print package section names from a package config file.
#
# Usage:
#   dnb_package_list_sections <config-file>

dnb_package_list_sections() {
  local config_file="${1:-}"

  if [[ "${1:-}" == '--help' ]]; then
    cat <<EOF_HELP
${FUNCNAME[0]} - list [packages.<name>] sections from a config file

Usage:
  ${FUNCNAME[0]} <config-file>
EOF_HELP
    return 0
  fi

  if [[ -z "${config_file}" || ! -f "${config_file}" ]]; then
    dnb_error "Package config file not found: ${config_file}"
    return 1
  fi

  awk '
    /^\[packages\.[A-Za-z0-9._-]+\][[:space:]]*$/ {
      line=$0
      sub(/^\[packages\./, "", line)
      sub(/\][[:space:]]*$/, "", line)
      print line
    }
  ' "${config_file}"
}

# dnb_package_read_paths
#
# Print raw path lines from one [packages.<name>] section.
#
# Usage:
#   dnb_package_read_paths <config-file> <package-name>

dnb_package_read_paths() {
  local config_file="${1:-}"
  local package_name="${2:-}"

  if [[ "${1:-}" == '--help' ]]; then
    cat <<EOF_HELP
${FUNCNAME[0]} - read path lines from a package section

Usage:
  ${FUNCNAME[0]} <config-file> <package-name>
EOF_HELP
    return 0
  fi

  if [[ -z "${config_file}" || ! -f "${config_file}" ]]; then
    dnb_error "Package config file not found: ${config_file}"
    return 1
  fi

  if [[ -z "${package_name}" ]]; then
    dnb_error 'Package name is required.'
    return 1
  fi

  awk -v target="${package_name}" '
    BEGIN { in_section=0 }
    /^\[packages\.[A-Za-z0-9._-]+\][[:space:]]*$/ {
      line=$0
      sub(/^\[packages\./, "", line)
      sub(/\][[:space:]]*$/, "", line)
      in_section = (line == target) ? 1 : 0
      next
    }
    /^\[/ {
      if (in_section == 1) {
        exit 0
      }
      next
    }
    in_section == 1 {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "" || line ~ /^[#;]/) {
        next
      }
      print line
    }
  ' "${config_file}"
}
