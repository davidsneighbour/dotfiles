# shellcheck shell=bash

# dnb_load_env
#
# Load and export environment variables from `~/.env` and `./.env`.
# Local values override home-level values.
#
# Parameters:
#   none
#
# Options:
#   --help      Show help output.
#   --verbose   Print progress messages.
#
# Behaviour:
#   * Sources `~/.env` first when readable.
#   * Sources `$(pwd -P)/.env` second when readable.
#   * Uses `set -a` so sourced variables are exported.
#   * Returns non-zero when sourcing fails.
#
# Examples:
#   dnb_load_env
#   dnb_load_env --verbose
#
# Requirements:
#   * bash

dnb_load_env() {
  local verbose='false'
  local home_env="${HOME}/.env"
  local local_env=''

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
      --help)
        cat <<EOF2
${FUNCNAME[0]} - load .env files from home and current directory

Usage:
  ${FUNCNAME[0]} [--verbose]
EOF2
        return 0
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

  local_env="$(pwd -P)/.env"

  if [[ -f "${home_env}" && -r "${home_env}" ]]; then
    [[ "${verbose}" == 'true' ]] && dnb_log info "Loading ${home_env}"
    set -a
    # shellcheck disable=SC1090
    source "${home_env}" || {
      set +a
      dnb_error "Failed to source ${home_env}"
      return 1
    }
    set +a
  fi

  if [[ -f "${local_env}" && -r "${local_env}" ]]; then
    [[ "${verbose}" == 'true' ]] && dnb_log info "Loading ${local_env}"
    set -a
    # shellcheck disable=SC1090
    source "${local_env}" || {
      set +a
      dnb_error "Failed to source ${local_env}"
      return 1
    }
    set +a
  fi

  return 0
}
