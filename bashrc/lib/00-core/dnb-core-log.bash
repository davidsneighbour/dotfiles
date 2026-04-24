# shellcheck shell=bash

# __dnb_log_level_to_priority
#
# Internal helper to map log levels to comparable numeric values.
__dnb_log_level_to_priority() {
  case "${1:-info}" in
  error) printf '0\n' ;;
  warn) printf '1\n' ;;
  info | success) printf '2\n' ;;
  dry) printf '3\n' ;;
  skip) printf '4\n' ;;
  *) printf '2\n' ;;
  esac
}

# dnb_log_init
#
# Initialise and print the shared setup logfile path.
#
# Parameters:
#   none
#
# Behaviour:
#   - Creates `~/.logs/` when missing.
#   - Sets DNB_SETUP_LOG_FILE if it is not already set.
#   - Prints the logfile path to stdout.
#
# Examples:
#   log_file="$(dnb_log_init)"
#
# Requirements:
#   - bash

dnb_log_init() {
  local log_dir="${HOME}/.logs"

  if [[ -z "${DNB_SETUP_LOG_FILE:-}" ]]; then
    mkdir -p "${log_dir}"
    DNB_SETUP_LOG_FILE="${log_dir}/setup-log-$(date +%Y%m%d-%H%M%S).log"
  fi

  printf '%s\n' "${DNB_SETUP_LOG_FILE}"
}

# dnb_log
#
# Unified logger for sourced helper functions and standalone helper scripts.
#
# Parameters:
#   level     Log level: error, warn, info, success, dry, skip.
#   message   Message text.
#
# Options:
#   --json    Print JSON output instead of formatted text.
#   --help    Show help output.
#
# Behaviour:
#   - Writes to console and to the shared logfile.
#   - Uses LOG_LEVEL filtering when set.
#   - Defaults to `~/.logs/setup-log-YYYYMMDD-HHMMSS.log`.
#
# Examples:
#   dnb_log info "Loaded local environment"
#   dnb_log --json warn "Fallback used"
#
# Requirements:
#   - bash
#   - date
#   - stat

dnb_log() {
  local json_mode='false'
  local level='info'
  local msg=''
  local logfile=''
  local timestamp=''
  local threshold=''
  local current=''
  local max_size=''

  if [[ "$#" -eq 0 || "${1:-}" == '--help' ]]; then
    cat <<EOF2
${FUNCNAME[0]} - unified logger

Usage:
  ${FUNCNAME[0]} [--json] <level> <message>
  ${FUNCNAME[0]} --help

Levels:
  error, warn, info, success, dry, skip
EOF2
    return 0
  fi

  if [[ "${1:-}" == '--json' ]]; then
    json_mode='true'
    shift
  fi

  level="${1:-info}"
  shift || true
  msg="${*}"

  if [[ -z "${msg}" ]]; then
    msg=''
  fi

  threshold="$(__dnb_log_level_to_priority "${LOG_LEVEL:-info}")"
  current="$(__dnb_log_level_to_priority "${level}")"
  if ((current > threshold)); then
    return 0
  fi

  logfile="${__LOGFILE:-${DNB_SETUP_LOG_FILE:-}}"
  if [[ -z "${logfile}" ]]; then
    logfile="$(dnb_log_init)"
  else
    mkdir -p "$(dirname "${logfile}")"
  fi

  max_size="${LOG_MAX_SIZE:-1048576}"
  if [[ -f "${logfile}" ]]; then
    if [[ "$(stat -c '%s' "${logfile}")" -gt "${max_size}" ]]; then
      mv "${logfile}" "${logfile}.1"
      : >"${logfile}"
    fi
  fi

  timestamp="$(date '+%b%d %H:%M:%S')"

  if [[ "${json_mode}" == 'true' ]]; then
    printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' "${timestamp}" "${level}" "${msg}"
    printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' "${timestamp}" "${level}" "${msg}" >>"${logfile}"
    return 0
  fi

  local color=''
  local reset='\033[0m'
  case "${level}" in
  error)
    color='\033[31m'
    ;;
  warn)
    color='\033[33m'
    ;;
  info)
    color='\033[36m'
    ;;
  debug)
    color='\033[36m'
    ;;
  trace)
    color='\033[36m'
    ;;
  success)
    color='\033[32m'
    ;;
  dry)
    color='\033[90m'
    ;;
  skip)
    color='\033[35m'
    ;;
  esac

  local padded_level=''
  printf -v padded_level '%-7s' "${level}"

  printf '%b%s %s%b %s\n' "${color}" "${timestamp}" "${padded_level}" "${reset}" "${msg}"
  printf '%s %s %s\n' "${timestamp}" "${padded_level}" "${msg}" >>"${logfile}"
}

# dnb_error
#
# Convenience wrapper for error logging.
#
# Parameters:
#   message  Error message.
#
# Examples:
#   dnb_error "Failed to create directory"
#
# Requirements:
#   - bash

dnb_error() {
  local message="${*:-Unknown error}"
  dnb_log error "${message}"
}
