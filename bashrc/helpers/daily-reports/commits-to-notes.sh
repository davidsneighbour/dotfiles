#!/bin/bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
LOG_DIR="${HOME}/.logs/daily-reports"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
LOG_FILE="${LOG_DIR}/setup-log-${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

show_help() {
  cat <<HELP
Usage:
  ${SCRIPT_NAME} [scope] [date options] [output options]

Description:
  Generate Markdown commit reports for one repository or many repositories.

Scope options (choose one; default is --repo .):
  --repo PATH          Report for a single repository.
  --dir PATH           Report for all direct child Git repositories in PATH.

Date options:
  --date YYYY-MM-DD    Report for a single day (default: today in --timezone).
  --from YYYY-MM-DD    Start date for a date range (inclusive).
  --to YYYY-MM-DD      End date for a date range (inclusive).

Output options:
  --timezone TZ        IANA timezone for day boundaries (default: Asia/Bangkok).
  --verbose            Print informational logs to STDERR.
  --help               Show this help output.

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --repo ~/github.com/davidsneighbour/dotfiles --date 2026-04-01
  ${SCRIPT_NAME} --dir ~/github.com/davidsneighbour --date 2026-04-01
  ${SCRIPT_NAME} --repo ~/github.com/davidsneighbour/dotfiles --from 2026-04-01 --to 2026-04-07
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

extract_repo_name() {
  local repo_path="$1"
  basename "${repo_path}"
}

extract_github_slug() {
  local repo_path="$1"
  local origin_url=""
  local slug=""

  if ! origin_url="$(git -C "${repo_path}" remote get-url origin 2>/dev/null)"; then
    return 1
  fi

  case "${origin_url}" in
  git@github.com:*.git)
    slug="${origin_url#git@github.com:}"
    slug="${slug%.git}"
    ;;
  git@github.com:*)
    slug="${origin_url#git@github.com:}"
    ;;
  https://github.com/*.git)
    slug="${origin_url#https://github.com/}"
    slug="${slug%.git}"
    ;;
  https://github.com/*)
    slug="${origin_url#https://github.com/}"
    ;;
  ssh://git@github.com/*.git)
    slug="${origin_url#ssh://git@github.com/}"
    slug="${slug%.git}"
    ;;
  ssh://git@github.com/*)
    slug="${origin_url#ssh://git@github.com/}"
    ;;
  *)
    return 1
    ;;
  esac

  if [[ -z "${slug}" || "${slug}" != */* ]]; then
    return 1
  fi

  printf '%s\n' "${slug}"
}

resolve_repo_label() {
  local repo_path="$1"
  local slug=""

  if slug="$(extract_github_slug "${repo_path}")"; then
    printf '%s\t%s\n' "${slug}" "https://github.com/${slug}"
    return 0
  fi

  local name
  name="$(extract_repo_name "${repo_path}")"
  printf '%s\t%s\n' "${name}" ""
}

compute_utc_window() {
  local input_date="$1"
  local timezone_name="$2"
  local start_utc=""
  local end_utc=""

  start_utc="$(env TZ="${timezone_name}" date -d "${input_date} 00:00:00" -u '+%Y-%m-%d %H:%M:%S')"
  end_utc="$(env TZ="${timezone_name}" date -d "${input_date} 23:59:59" -u '+%Y-%m-%d %H:%M:%S')"

  printf '%s\t%s\n' "${start_utc}" "${end_utc}"
}

collect_repositories() {
  local scope_mode="$1"
  local scope_path="$2"
  local repo_path=""

  if [[ "${scope_mode}" == "repo" ]]; then
    if [[ ! -d "${scope_path}" ]]; then
      log_error "Repository path does not exist: ${scope_path}"
      exit 1
    fi

    if ! is_git_repository "${scope_path}"; then
      log_error "Path is not a Git repository: ${scope_path}"
      exit 1
    fi

    printf '%s\n' "${scope_path}"
    return 0
  fi

  if [[ ! -d "${scope_path}" ]]; then
    log_error "Directory does not exist: ${scope_path}"
    exit 1
  fi

  shopt -s nullglob
  for repo_path in "${scope_path}"/*; do
    if [[ ! -d "${repo_path}" ]]; then
      continue
    fi

    if is_git_repository "${repo_path}"; then
      printf '%s\n' "${repo_path}"
    else
      log_info "Skipping non-repository directory: ${repo_path}"
    fi
  done
}

print_report_for_repo_date() {
  local repo_path="$1"
  local report_date="$2"
  local timezone_name="$3"
  local start_utc=""
  local end_utc=""
  local git_output=""
  local repo_label=""
  local repo_url=""

  read -r start_utc end_utc < <(compute_utc_window "${report_date}" "${timezone_name}")

  if ! git_output="$({
    env TZ="${timezone_name}" git -C "${repo_path}" log \
      --since="${start_utc} +0000" \
      --until="${end_utc} +0000" \
      --date='format-local:%H:%M' \
      --pretty='format:%ad%x09%h%x09%H%x09%s'
  } 2>/dev/null)"; then
    log_warn "git log failed for ${repo_path} on ${report_date}"
    return 0
  fi

  if [[ -z "${git_output}" ]]; then
    return 0
  fi

  read -r repo_label repo_url < <(resolve_repo_label "${repo_path}")

  if [[ -n "${repo_url}" ]]; then
    printf '### %s · [%s](%s)\n\n' "${report_date}" "${repo_label}" "${repo_url}"
  else
    printf '### %s · %s\n\n' "${report_date}" "${repo_label}"
  fi

  while IFS=$'\t' read -r commit_time short_hash full_hash subject; do
    if [[ -z "${full_hash}" ]]; then
      continue
    fi

    if [[ -n "${repo_url}" ]]; then
      printf -- '- **%s:** [[%s](%s/commit/%s)] %s\n' \
        "${commit_time}" \
        "${short_hash}" \
        "${repo_url}" \
        "${full_hash}" \
        "${subject}"
    else
      # shellcheck disable=SC2016
      printf -- '- **%s:** `%s` %s\n' \
        "${commit_time}" \
        "${short_hash}" \
        "${subject}"
    fi
  done <<<"${git_output}"

  printf '\n'
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

main() {
  local scope_mode="repo"
  local scope_path="."
  local timezone_name="Asia/Bangkok"
  local single_date=""
  local from_date=""
  local to_date=""
  local report_date=""
  local repo_path=""
  local -a repos=()
  local -a dates=()

  VERBOSE="false"

  if [[ $# -eq 0 ]]; then
    :
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --repo)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --repo"
        show_help
        exit 1
      fi
      scope_mode="repo"
      scope_path="$2"
      shift 2
      ;;
    --dir)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --dir"
        show_help
        exit 1
      fi
      scope_mode="dir"
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

  require_command git
  require_command date
  validate_timezone "${timezone_name}"

  if [[ -n "${single_date}" && ( -n "${from_date}" || -n "${to_date}" ) ]]; then
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

  while IFS= read -r repo_path; do
    repos+=("${repo_path}")
  done < <(collect_repositories "${scope_mode}" "${scope_path}")

  if [[ "${#repos[@]}" -eq 0 ]]; then
    log_warn "No repositories found in: ${scope_path}"
    exit 0
  fi

  log_info "Log file: ${LOG_FILE}"
  log_info "Repositories: ${#repos[@]}"
  log_info "Days in scope: ${#dates[@]}"

  for report_date in "${dates[@]}"; do
    for repo_path in "${repos[@]}"; do
      print_report_for_repo_date "${repo_path}" "${report_date}" "${timezone_name}"
    done
  done
}

main "$@"
