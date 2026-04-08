# shellcheck shell=bash

# Compatibility aliases for older scripts. Remove once all callers migrated.

# searchfor __dnb_check_requirements --path /home/patrick

__dnb_check_requirements() { dnb_check_requirements "$@"; }
__dnb_load_env() { dnb_load_env "$@"; }
__dnb_log() {
  if [[ "$#" -ge 2 ]]; then
    dnb_log "${2}" "${1}"
  else
    dnb_log info "$*"
  fi
}
__dnb_init_log() { dnb_log_init; }
__dnb_error() { dnb_error "$@"; }
__dnb_create_directory() { dnb_create_directory "$@"; }
path_sanitise() { dnb_path_sanitise "$@"; }
execute() {
  printf 'DEPRECATED: execute used eval and was replaced by dnb_execute_lines.\n' >&2
  return 1
}
package() { dnb_archive_create "$@"; }
unpackage() { dnb_archive_extract "$@"; }
