#!/bin/bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMATTER_PATH="${SCRIPT_DIR}/commits-to-notes.sh"
LOG_DIR="${HOME}/.logs/daily-reports"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
LOG_FILE="${LOG_DIR}/setup-log-${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

show_help() {
  cat <<HELP
Usage:
  ${SCRIPT_NAME} [scope] [date options] [obsidian options]

Description:
  Generate commit reports and append them to Obsidian daily notes.

Scope options (choose one; default is --repo .):
  --repo PATH          Use one repository.
  --dir PATH           Use all direct child repositories of PATH.

Date options:
  --date YYYY-MM-DD    One day (default: today in --timezone).
  --from YYYY-MM-DD    Start date for date range (inclusive).
  --to YYYY-MM-DD      End date for date range (inclusive).

Obsidian options:
  --timezone TZ        IANA timezone for day boundaries (default: Asia/Bangkok).
  --verbose            Print informational logs to STDERR.
  --help               Show this help output.

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --repo ~/github.com/davidsneighbour/dotfiles --date 2026-04-01
  ${SCRIPT_NAME} --dir ~/github.com/davidsneighbour --date 2026-04-01
  ${SCRIPT_NAME} --dir ~/github.com/davidsneighbour --from 2026-04-01 --to 2026-04-07 --timezone UTC
HELP
}

log_line() {
  local level="$1"
  local message="$2"
  printf '%s %s\n' "${level}" "${message}" >>"${LOG_FILE}"

  if [[ "${level}" == "ERROR" || "${level}" == "WARN" || "${VERBOSE}" == "true" ]]; then
    printf '%s %s\n' "${level}" "${message}" >&2
  fi
}

log_info() {
  log_line "INFO" "$1"
}

log_warn() {
  log_line "WARN" "$1"
}

log_error() {
  log_line "ERROR" "$1"
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log_error "Required command not found: ${command_name}"
    exit 1
  fi
}

validate_date() {
  local input_date="$1"

  if ! date -d "${input_date}" '+%Y-%m-%d' >/dev/null 2>&1; then
    log_error "Invalid date: ${input_date}"
    exit 1
  fi
}

validate_timezone() {
  local timezone_name="$1"

  if ! env TZ="${timezone_name}" date -d '2000-01-01 00:00:00' '+%Y-%m-%d %H:%M:%S' >/dev/null 2>&1; then
    log_error "Invalid timezone: ${timezone_name}"
    exit 1
  fi
}

build_note_path() {
  local input_date="$1"
  local year=""
  local month_number=""
  local month_name=""
  local weekday=""
  local full_date=""

  year="$(date -d "${input_date}" '+%Y')"
  month_number="$(date -d "${input_date}" '+%m')"
  month_name="$(date -d "${input_date}" '+%B')"
  weekday="$(date -d "${input_date}" '+%A')"
  full_date="$(date -d "${input_date}" '+%Y-%m-%d')"

  printf '10 Daily Notes/%s/%s-%s/%s-%s.md\n' \
    "${year}" \
    "${month_number}" \
    "${month_name}" \
    "${full_date}" \
    "${weekday}"
}

print_date_sequence() {
  local from_date="$1"
  local to_date="$2"
  local current_date="${from_date}"

  while [[ "${current_date}" < "${to_date}" || "${current_date}" == "${to_date}" ]]; do
    printf '%s\n' "${current_date}"
    current_date="$(date -I -d "${current_date} + 1 day")"
  done
}

append_for_day() {
  local scope_flag="$1"
  local scope_path="$2"
  local report_date="$3"
  local timezone_name="$4"
  local note_path=""
  local report_content=""

  note_path="$(build_note_path "${report_date}")"

  if ! report_content="$(${FORMATTER_PATH} "${scope_flag}" "${scope_path}" --date "${report_date}" --timezone "${timezone_name}")"; then
    log_warn "Formatter failed for ${report_date}"
    return 0
  fi

  if [[ -z "${report_content}" ]]; then
    log_info "No commits found for ${report_date}; skipping append"
    return 0
  fi

  if obsidian append path="${note_path}" content="${report_content}"; then
    log_info "Appended report to ${note_path}"
  else
    log_warn "Failed to append report to ${note_path}"
  fi
}

main() {
  local scope_flag="--repo"
  local scope_path="."
  local timezone_name="Asia/Bangkok"
  local single_date=""
  local from_date=""
  local to_date=""
  local report_date=""
  local -a dates=()

  VERBOSE="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --repo)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --repo"
        show_help
        exit 1
      fi
      scope_flag="--repo"
      scope_path="$2"
      shift 2
      ;;
    --dir)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --dir"
        show_help
        exit 1
      fi
      scope_flag="--dir"
      scope_path="$2"
      shift 2
      ;;
    --date)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --date"
        show_help
        exit 1
      fi
      single_date="$2"
      shift 2
      ;;
    --from)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --from"
        show_help
        exit 1
      fi
      from_date="$2"
      shift 2
      ;;
    --to)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --to"
        show_help
        exit 1
      fi
      to_date="$2"
      shift 2
      ;;
    --timezone)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --timezone"
        show_help
        exit 1
      fi
      timezone_name="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE="true"
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
    esac
  done

  require_command obsidian
  require_command date
  validate_timezone "${timezone_name}"

  if [[ ! -x "${FORMATTER_PATH}" ]]; then
    log_error "Formatter not found or not executable: ${FORMATTER_PATH}"
    exit 1
  fi

  if [[ -n "${single_date}" && (-n "${from_date}" || -n "${to_date}") ]]; then
    log_error "Use either --date or --from/--to, not both"
    show_help
    exit 1
  fi

  if [[ -n "${single_date}" ]]; then
    validate_date "${single_date}"
    dates+=("${single_date}")
  elif [[ -n "${from_date}" || -n "${to_date}" ]]; then
    if [[ -z "${from_date}" || -z "${to_date}" ]]; then
      log_error "Both --from and --to are required for a range"
      show_help
      exit 1
    fi

    validate_date "${from_date}"
    validate_date "${to_date}"

    if [[ "${from_date}" > "${to_date}" ]]; then
      log_error "--from must be earlier than or equal to --to"
      exit 1
    fi

    while IFS= read -r report_date; do
      dates+=("${report_date}")
    done < <(print_date_sequence "${from_date}" "${to_date}")
  else
    dates+=("$(env TZ="${timezone_name}" date '+%Y-%m-%d')")
  fi

  log_info "Log file: ${LOG_FILE}"

  for report_date in "${dates[@]}"; do
    append_for_day "${scope_flag}" "${scope_path}" "${report_date}" "${timezone_name}"
  done
}

main "$@"
