# shellcheck shell=bash

# __dnb_warn_deprecated_release_helper
__dnb_warn_deprecated_release_helper() {
  local helper_name="${1:-unknown}"
  local message="DEPRECATED: ${helper_name} is obsolete and will be removed from bashrc/lib. Move release logic into existing scripts or standalone helpers under bashrc/helpers."
  if declare -F dnb_error >/dev/null 2>&1; then
    dnb_error warn "${message}"
  else
    printf '%s\n' "${message}" >&2
  fi
}
