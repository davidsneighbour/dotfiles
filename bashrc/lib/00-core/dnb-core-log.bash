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

# __dnb_json_escape
#
# Print TEXT as JSON string content (without the surrounding quotes).
# Escapes backslash, quote, and all control characters.
__dnb_json_escape() {
  local text="${1-}"
  local out='' char='' code=0
  local i=0

  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\n'/\\n}"
  text="${text//$'\t'/\\t}"
  text="${text//$'\r'/\\r}"

  if [[ "${text}" != *[[:cntrl:]]* ]]; then
    printf '%s' "${text}"
    return 0
  fi

  for ((i = 0; i < ${#text}; i++)); do
    char="${text:i:1}"
    if [[ "${char}" == [[:cntrl:]] ]]; then
      printf -v code '%d' "'${char}"
      printf -v char '\\u%04x' "${code}"
    fi
    out+="${char}"
  done
  printf '%s' "${out}"
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
    DNB_SETUP_LOG_FILE="${log_dir}/default-$(date +%Y%m%d-%H%M%S).log"
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
#   - Writes console lines to stderr, so stdout stays free for results,
#     and writes every line to the shared logfile.
#   - --json prints the JSON line to stdout (unchanged).
#   - Uses LOG_LEVEL filtering when set.
#   - Colours console output only for a terminal stderr (DNB_COLOR_MODE=auto)
#     and never emits a reset escape without colour.
#   - JSON mode escapes quotes, backslashes, and control characters.
#   - Defaults to `~/.logs/default-YYYYMMDD-HHMMSS.log`.
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
    local json_line=''
    printf -v json_line '{"timestamp":"%s","level":"%s","message":"%s"}' \
      "$(__dnb_json_escape "${timestamp}")" "$(__dnb_json_escape "${level}")" "$(__dnb_json_escape "${msg}")"
    printf '%s\n' "${json_line}"
    printf '%s\n' "${json_line}" >>"${logfile}"
    return 0
  fi

  local color=''
  local color2=''
  local reset=''

  # In auto mode, only colour the console when stderr is a terminal.
  if [[ "${DNB_COLOR_MODE:-auto}" != 'auto' || -t 2 ]]; then
    color="$(__dnb_log_color "${level}")"
    color2="$(__dnb_log_color "debug")"
  fi
  if [[ -n "${color}" || -n "${color2}" ]]; then
    reset='\033[0m'
  fi

  local padded_level=''
  printf -v padded_level '%-7s' "${level}"

  printf '%b%s %b%s%b %s\n' "${color2}" "${timestamp}" "${color}" "${padded_level}" "${reset}" "${msg}" >&2
  printf '%s %s %s\n' "${timestamp}" "${padded_level}" "${msg}" >>"${logfile}"
}
