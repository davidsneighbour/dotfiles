# shellcheck shell=bash

# __dnb_warn_deprecated_release_helper
__dnb_warn_deprecated_release_helper() {
  local helper_name="${1:-unknown}"
  local message="DEPRECATED: ${helper_name} is obsolete and will be removed from _lib. Move release logic into workflow scripts or standalone helpers under bashrc/helpers."
  if declare -F dnb_error >/dev/null 2>&1; then
    dnb_error warn "${message}"
  else
    printf '%s\n' "${message}" >&2
  fi
}

get_next_version() {
  __dnb_warn_deprecated_release_helper "get_next_version"
  return 1
}

create_changelog() {
  __dnb_warn_deprecated_release_helper "create_changelog"
  return 1
}

create_ghrelease() {
  __dnb_warn_deprecated_release_helper "create_ghrelease"
  return 1
}

update_citation() {
  __dnb_warn_deprecated_release_helper "update_citation"
  return 1
}

__dnb_create_repopath() {
  __dnb_warn_deprecated_release_helper "__dnb_create_repopath"
  return 1
}
