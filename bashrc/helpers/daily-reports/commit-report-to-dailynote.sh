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
  --usernames PATH     Use all username directories under PATH. Each username
                       directory is handled like --dir.

Date options:
  --date YYYY-MM-DD    One day (default: today in --timezone).
  --from YYYY-MM-DD    Start date for date range (inclusive).
  --to YYYY-MM-DD      End date for date range (inclusive).

Obsidian options:
  --timezone TZ        IANA timezone for day boundaries (default: Asia/Bangkok).
  --headline-with-date Include the report date in repository headlines.
  --verbose            Print informational logs to STDERR.
  --help               Show this help output.

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --repo ~/github.com/davidsneighbour/dotfiles --date 2026-04-01
  ${SCRIPT_NAME} --dir ~/github.com/davidsneighbour --date 2026-04-01
  ${SCRIPT_NAME} --usernames ~/github.com --date 2026-04-01
  ${SCRIPT_NAME} --date 2026-04-01 --headline-with-date
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

is_git_repository() {
  local repo_path="$1"
  git -C "${repo_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1
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

print_username_directories() {
  local root_path="$1"
  local username_path=""

  if [[ ! -d "${root_path}" ]]; then
    log_error "Usernames root path does not exist: ${root_path}"
    return 1
  fi

  shopt -s nullglob
  for username_path in "${root_path}"/*; do
    if [[ -d "${username_path}" ]]; then
      printf '%s\n' "${username_path}"
    fi
  done
}

build_report_content() {
  local scope_flag="$1"
  local scope_path="$2"
  local report_date="$3"
  local timezone_name="$4"
  local include_headline_date="$5"
  local report_content=""
  local username_path=""
  local username_report=""
  local -a formatter_args=()

  if [[ "${scope_flag}" != "--usernames" ]]; then
    formatter_args=(
      "${scope_flag}"
      "${scope_path}"
      --date "${report_date}"
      --timezone "${timezone_name}"
    )

    if [[ "${include_headline_date}" == "true" ]]; then
      formatter_args+=(--headline-with-date)
    fi

    "${FORMATTER_PATH}" "${formatter_args[@]}"
    return $?
  fi

  while IFS= read -r username_path; do
    formatter_args=(
      --dir
      "${username_path}"
      --date "${report_date}"
      --timezone "${timezone_name}"
    )

    if [[ "${include_headline_date}" == "true" ]]; then
      formatter_args+=(--headline-with-date)
    fi

    if ! username_report="$(${FORMATTER_PATH} "${formatter_args[@]}")"; then
      log_warn "Formatter failed for username directory ${username_path} on ${report_date}"
      continue
    fi

    if [[ -n "${username_report}" ]]; then
      if [[ -n "${report_content}" ]]; then
        report_content+=$'\n\n'
      fi
      report_content+="${username_report}"
    fi
  done < <(print_username_directories "${scope_path}")

  if [[ -z "${report_content}" ]]; then
    log_warn "No reports generated from usernames root ${scope_path} for ${report_date}"
  fi

  printf '%s\n' "${report_content}"
}

replace_section_for_day() {
  local scope_flag="$1"
  local scope_path="$2"
  local report_date="$3"
  local timezone_name="$4"
  local include_headline_date="$5"
  local note_path=""
  local report_content=""
  local note_content=""
  local updated_note_content=""
  local section_start='%%daily-repo-logs-start%%'
  local section_end='%%daily-repo-logs-end%%'

  note_path="$(build_note_path "${report_date}")"

  if ! report_content="$(build_report_content "${scope_flag}" "${scope_path}" "${report_date}" "${timezone_name}" "${include_headline_date}")"; then
    log_warn "Formatter failed for ${report_date}"
    return 0
  fi

  if ! note_content="$(obsidian read path="${note_path}")"; then
    log_warn "Failed to read note content from ${note_path}"
    return 0
  fi

  if ! updated_note_content="$(
    NOTE_CONTENT="${note_content}" \
      REPORT_CONTENT="${report_content}" \
      SECTION_START="${section_start}" \
      SECTION_END="${section_end}" \
      python3 - <<'PY'
import os
import re
import sys

note_content = os.environ["NOTE_CONTENT"]
report_content = os.environ["REPORT_CONTENT"].strip("\n")
section_start = os.environ["SECTION_START"]
section_end = os.environ["SECTION_END"]

pattern = re.compile(
    rf"(^[ \t]*{re.escape(section_start)}[ \t]*\n)(.*?)(^[ \t]*{re.escape(section_end)}[ \t]*$)",
    re.MULTILINE | re.DOTALL,
)

replacement = (
    f"\n{section_start}\n\n"
    f"{report_content}\n\n"
    f"{section_end}\n"
)

updated_content, replacements = pattern.subn(replacement, note_content, count=1)
if replacements == 0:
    print("Markers not found", file=sys.stderr)
    sys.exit(1)

print(updated_content, end="")
PY
  )"; then
    log_warn "Failed to replace repository work section for ${note_path}"
    return 0
  fi

  if obsidian create overwrite path="${note_path}" content="${updated_note_content}"; then
    log_info "Replaced repository work section in ${note_path}"
  else
    log_warn "Failed to write updated note to ${note_path}"
  fi
}

main() {
  local scope_flag="--repo"
  local scope_path="."
  local timezone_name="Asia/Bangkok"
  local single_date=""
  local from_date=""
  local to_date=""
  local include_headline_date="false"
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
    --usernames)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --usernames"
        show_help
        exit 1
      fi
      scope_flag="--usernames"
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
    --headline-with-date)
      include_headline_date="true"
      shift
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
  require_command git
  require_command date
  require_command python3
  validate_timezone "${timezone_name}"

  if [[ ! -x "${FORMATTER_PATH}" ]]; then
    log_error "Formatter not found or not executable: ${FORMATTER_PATH}"
    exit 1
  fi

  if [[ "${scope_flag}" == "--repo" && "${scope_path}" == "." ]]; then
    if ! is_git_repository "${scope_path}"; then
      log_error "Current directory is not a Git repository"
      show_help
      exit 1
    fi
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
    replace_section_for_day "${scope_flag}" "${scope_path}" "${report_date}" "${timezone_name}" "${include_headline_date}"
  done
}

main "$@"
