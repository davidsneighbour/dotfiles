#!/bin/bash

set -euo pipefail

##
# Show the help output for this script.
#
# Parameters:
#   None.
#
# Options:
#   None.
#
# Behaviour:
#   Prints usage information, supported options, exit behaviour, and output format.
#
# Examples:
#   show_help
#
# Requirements:
#   basename
##
show_help() {
  local cmd
  cmd="$(basename "$0")"

  cat <<EOF
Usage:
  ${cmd} --repo /path/to/repository --date YYYY-MM-DD [--timezone Asia/Bangkok]

Description:
  Generate a Markdown commit report block for a single Git repository for the
  selected day, interpreted in the selected timezone.

Options:
  --repo PATH         Path to the Git repository
  --date YYYY-MM-DD   Date to report
  --timezone TZ       IANA timezone name
                      Default: Asia/Bangkok
  --help              Show this help output

Output format:
  ### [owner/repo](https://github.com/owner/repo)

  - 10:34 [[83c4571](https://github.com/owner/repo/commit/fullhash)] Commit subject

  The block ends with two trailing newlines.

Behaviour:
  * Prints nothing if no commits were found for the selected day.
  * Prints nothing if the repository is invalid or unsupported.
  * Logs warnings and errors to STDERR only.

Examples:
  ${cmd} --repo ~/github.com/davidsneighbour/dotfiles --date 2026-04-01
  ${cmd} --repo ~/github.com/davidsneighbour/dotfiles --date 2026-04-01 --timezone Asia/Bangkok

Requirements:
  * git
  * date (GNU date)
EOF
}

##
# Print an informational log line to STDERR.
#
# Parameters:
#   \$*  Message text.
#
# Options:
#   None.
#
# Behaviour:
#   Prefixes the message with INFO and writes it to STDERR.
#
# Examples:
#   log_info "Scanning repository"
#
# Requirements:
#   printf
##
log_info() {
  printf 'INFO %s\n' "$*" >&2
}

##
# Print a warning log line to STDERR.
#
# Parameters:
#   \$*  Message text.
#
# Options:
#   None.
#
# Behaviour:
#   Prefixes the message with WARN and writes it to STDERR.
#
# Examples:
#   log_warn "Repository has no GitHub origin"
#
# Requirements:
#   printf
##
log_warn() {
  printf 'WARN %s\n' "$*" >&2
}

##
# Print an error log line to STDERR.
#
# Parameters:
#   \$*  Message text.
#
# Options:
#   None.
#
# Behaviour:
#   Prefixes the message with ERROR and writes it to STDERR.
#
# Examples:
#   log_error "Missing required option"
#
# Requirements:
#   printf
##
log_error() {
  printf 'ERROR %s\n' "$*" >&2
}

##
# Verify that a required command exists.
#
# Parameters:
#   \$1  Command name.
#
# Options:
#   None.
#
# Behaviour:
#   Exits with status 1 if the command is not available.
#
# Examples:
#   require_command git
#
# Requirements:
#   command
##
require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log_error "Required command not found: ${command_name}"
    exit 1
  fi
}

##
# Validate that the provided date is parseable as YYYY-MM-DD.
#
# Parameters:
#   \$1  Date string.
#
# Options:
#   None.
#
# Behaviour:
#   Exits with status 1 if the date cannot be parsed.
#
# Examples:
#   validate_date "2026-04-01"
#
# Requirements:
#   date
##
validate_date() {
  local input_date="$1"

  if ! date -d "${input_date}" '+%Y-%m-%d' >/dev/null 2>&1; then
    log_error "Invalid date: ${input_date}"
    exit 1
  fi
}

##
# Validate that the timezone can be used by GNU date.
#
# Parameters:
#   \$1  IANA timezone name.
#
# Options:
#   None.
#
# Behaviour:
#   Exits with status 1 if the timezone is invalid.
#
# Examples:
#   validate_timezone "Asia/Bangkok"
#
# Requirements:
#   env
#   date
##
validate_timezone() {
  local timezone_name="$1"

  if ! env TZ="${timezone_name}" date -d '2000-01-01 00:00:00' '+%Y-%m-%d %H:%M:%S' >/dev/null 2>&1; then
    log_error "Invalid timezone: ${timezone_name}"
    exit 1
  fi
}

##
# Check whether the supplied path is a valid Git working tree.
#
# Parameters:
#   \$1  Repository path.
#
# Options:
#   None.
#
# Behaviour:
#   Returns success if the path is inside a Git work tree.
#
# Examples:
#   if is_git_repository "/path/to/repo"; then
#     echo "ok"
#   fi
#
# Requirements:
#   git
##
is_git_repository() {
  local repo_path="$1"

  git -C "${repo_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

##
# Extract the GitHub owner/repository slug from the origin remote.
#
# Parameters:
#   \$1  Repository path.
#
# Options:
#   None.
#
# Behaviour:
#   Prints owner/repo to STDOUT on success.
#   Returns non-zero if the repository has no supported GitHub origin.
#
# Examples:
#   slug="$(extract_github_slug "/path/to/repo")"
#
# Requirements:
#   git
#   printf
##
extract_github_slug() {
  local repo_path="$1"
  local origin_url=""
  local slug=""

  if ! origin_url="$(git -C "${repo_path}" remote get-url origin 2>/dev/null)"; then
    log_warn "Could not read origin remote for ${repo_path}"
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
    log_warn "Unsupported or non-GitHub origin for ${repo_path}: ${origin_url}"
    return 1
    ;;
  esac

  if [[ -z "${slug}" || "${slug}" != */* ]]; then
    log_warn "Could not derive owner/repo slug from origin URL: ${origin_url}"
    return 1
  fi

  printf '%s\n' "${slug}"
}

##
# Compute the UTC start and end timestamps for a date in a chosen timezone.
#
# Parameters:
#   \$1  Date string in YYYY-MM-DD format.
#   \$2  Timezone name.
#
# Options:
#   None.
#
# Behaviour:
#   Prints two tab-separated UTC timestamps:
#     start_utc<TAB>end_utc
#
# Examples:
#   read -r start_utc end_utc < <(compute_utc_window "2026-04-01" "Asia/Bangkok")
#
# Requirements:
#   env
#   date
#   printf
##
compute_utc_window() {
  local input_date="$1"
  local timezone_name="$2"
  local start_utc=""
  local end_utc=""

  start_utc="$(env TZ="${timezone_name}" date -d "${input_date} 00:00:00" -u '+%Y-%m-%d %H:%M:%S')"
  end_utc="$(env TZ="${timezone_name}" date -d "${input_date} 23:59:59" -u '+%Y-%m-%d %H:%M:%S')"

  printf '%s\t%s\n' "${start_utc}" "${end_utc}"
}

##
# Generate the Markdown commit block for one repository and one day.
#
# Parameters:
#   \$1  Repository path.
#   \$2  Date string in YYYY-MM-DD format.
#   \$3  Timezone name.
#
# Options:
#   None.
#
# Behaviour:
#   Prints a Markdown block to STDOUT.
#   Prints nothing if no commits are present.
#   Logs recoverable issues to STDERR.
#
# Examples:
#   generate_report_block "/path/to/repo" "2026-04-01" "Asia/Bangkok"
#
# Requirements:
#   git
#   date
#   printf
##
generate_report_block() {
  local repo_path="$1"
  local report_date="$2"
  local timezone_name="$3"
  local github_slug=""
  local repo_url=""
  local start_utc=""
  local end_utc=""
  local git_output=""

  if [[ ! -d "${repo_path}" ]]; then
    log_warn "Repository path does not exist: ${repo_path}"
    return 0
  fi

  if ! is_git_repository "${repo_path}"; then
    log_warn "Not a Git repository: ${repo_path}"
    return 0
  fi

  if ! github_slug="$(extract_github_slug "${repo_path}")"; then
    return 0
  fi

  repo_url="https://github.com/${github_slug}"

  read -r start_utc end_utc < <(compute_utc_window "${report_date}" "${timezone_name}")

  if ! git_output="$(
    env TZ="${timezone_name}" git -C "${repo_path}" log \
      --since="${start_utc} +0000" \
      --until="${end_utc} +0000" \
      --date='format-local:%H:%M' \
      --pretty='format:%ad%x09%h%x09%H%x09%s' 2>/dev/null
  )"; then
    log_warn "git log failed for ${repo_path}"
    return 0
  fi

  if [[ -z "${git_output}" ]]; then
    return 0
  fi

  printf '### [%s](%s)\n\n' "${github_slug}" "${repo_url}"

  while IFS=$'\t' read -r commit_time short_hash full_hash subject; do
    if [[ -z "${full_hash}" ]]; then
      continue
    fi

    printf -- '- **%s:** \[[%s](%s/commit/%s)\] %s\n' \
      "${commit_time}" \
      "${short_hash}" \
      "${repo_url}" \
      "${full_hash}" \
      "${subject}"
  done <<<"${git_output}"

  printf '\n\n'
}

##
# Main program entry point.
#
# Parameters:
#   Command-line arguments.
#
# Options:
#   --repo
#   --date
#   --timezone
#   --help
#
# Behaviour:
#   Parses input, validates configuration, and prints a Markdown block for one repository.
#
# Examples:
#   main --repo ~/github.com/davidsneighbour/dotfiles --date 2026-04-01
#
# Requirements:
#   git
#   date
##
main() {
  local repo_path=""
  local report_date=""
  local timezone_name="Asia/Bangkok"

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --repo)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --repo"
        show_help
        exit 1
      fi
      repo_path="$2"
      shift 2
      ;;
    --date)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --date"
        show_help
        exit 1
      fi
      report_date="$2"
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

  if [[ -z "${repo_path}" || -z "${report_date}" ]]; then
    log_error "Both --repo and --date are required"
    show_help
    exit 1
  fi

  require_command git
  require_command date
  validate_date "${report_date}"
  validate_timezone "${timezone_name}"

  generate_report_block "${repo_path}" "${report_date}" "${timezone_name}"
}

main "$@"
