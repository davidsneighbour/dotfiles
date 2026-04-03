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
#   Prints usage information, supported options, examples, and notes.
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
  ${cmd} --date YYYY-MM-DD [--dir PATH] [--timezone Asia/Bangkok] [--formatter PATH]

Description:
  Scan the direct subfolders of a directory, generate one Markdown commit block
  per repository for the selected day, and append each successful block to the
  matching Obsidian daily note.

Options:
  --date YYYY-MM-DD   Date to report
  --dir PATH          Parent directory containing repository subfolders
                      Default: ${HOME}/github.com/davidsneighbour
  --timezone TZ       IANA timezone name
                      Default: Asia/Bangkok
  --formatter PATH    Path or command name for the single-repository formatter
                      Default: commits-to-notes.sh
  --help              Show this help output

Behaviour:
  * Appends one repository block at a time.
  * Continues even if one repository fails.
  * Logs repository issues to STDERR only.
  * Does not write note output for broken or empty repositories.

Examples:
  ${cmd} --date 2026-04-01
  ${cmd} --date 2026-04-01 --dir ~/github.com/davidsneighbour
  ${cmd} --date 2026-04-01 --dir ~/github.com/davidsneighbour --timezone Asia/Bangkok

Requirements:
  * obsidian
  * date (GNU date)
  * commits-to-notes.sh
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
#   log_info "Target note resolved"
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
#   log_warn "Append failed for repository"
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
#   log_error "Missing required command"
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
#   require_command obsidian
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
# Build the Obsidian daily note path from a date.
#
# Parameters:
#   \$1  Date string in YYYY-MM-DD format.
#
# Options:
#   None.
#
# Behaviour:
#   Prints the relative daily note path in the format:
#   10 Daily Notes/YYYY/MM-MMMM/YYYY-MM-DD-DDDD.md
#
# Examples:
#   build_note_path "2026-04-01"
#
# Requirements:
#   date
#   printf
##
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

##
# Determine whether the formatter path is directly executable or available in PATH.
#
# Parameters:
#   \$1  Formatter command or path.
#
# Options:
#   None.
#
# Behaviour:
#   Returns success if the formatter can be invoked.
#
# Examples:
#   if formatter_available "commits-to-notes.sh"; then
#     echo "ok"
#   fi
#
# Requirements:
#   command
##
formatter_available() {
  local formatter_path="$1"

  if command -v "${formatter_path}" >/dev/null 2>&1; then
    return 0
  fi

  if [[ -x "${formatter_path}" ]]; then
    return 0
  fi

  return 1
}

##
# Run the formatter for a single repository and append the result to the daily note.
#
# Parameters:
#   \$1  Formatter command or path.
#   \$2  Repository path.
#   \$3  Report date.
#   \$4  Timezone name.
#   \$5  Target Obsidian note path.
#
# Options:
#   None.
#
# Behaviour:
#   Appends one block to the note if output exists.
#   Logs all issues to STDERR and continues without failing the full script.
#
# Examples:
#   process_repository "commits-to-notes.sh" "/path/to/repo" "2026-04-01" "Asia/Bangkok" "10 Daily Notes/..."
#
# Requirements:
#   obsidian
#   printf
##
process_repository() {
  local formatter_path="$1"
  local repo_path="$2"
  local report_date="$3"
  local timezone_name="$4"
  local note_path="$5"
  local repo_output=""

  log_info "Checking ${repo_path}"

  if ! repo_output="$("${formatter_path}" --repo "${repo_path}" --date "${report_date}" --timezone "${timezone_name}")"; then
    log_warn "Formatter failed for ${repo_path}"
    return 0
  fi

  if [[ -z "${repo_output}" ]]; then
    log_info "No output for ${repo_path}"
    return 0
  fi

  if obsidian append path="${note_path}" content="${repo_output}"; then
    log_info "Appended commit block for ${repo_path}"
  else
    log_warn "Failed to append commit block for ${repo_path}"
  fi
}

##
# Main program entry point.
#
# Parameters:
#   Command-line arguments.
#
# Options:
#   --date
#   --dir
#   --timezone
#   --formatter
#   --help
#
# Behaviour:
#   Scans direct subfolders of the target directory and appends one Markdown
#   block per successful repository report.
#
# Examples:
#   main --date 2026-04-01 --dir ~/github.com/davidsneighbour
#
# Requirements:
#   obsidian
#   date
#   commits-to-notes.sh
##
main() {
  local report_date=""
  local parent_dir="${HOME}/github.com/davidsneighbour"
  local timezone_name="Asia/Bangkok"
  local formatter_path="commits-to-notes.sh"
  local note_path=""
  local repo_path=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --date)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --date"
        show_help
        exit 1
      fi
      report_date="$2"
      shift 2
      ;;
    --dir)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --dir"
        show_help
        exit 1
      fi
      parent_dir="$2"
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
    --formatter)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --formatter"
        show_help
        exit 1
      fi
      formatter_path="$2"
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

  if [[ -z "${report_date}" ]]; then
    log_error "--date is required"
    show_help
    exit 1
  fi

  require_command obsidian
  require_command date
  validate_date "${report_date}"
  validate_timezone "${timezone_name}"

  if [[ ! -d "${parent_dir}" ]]; then
    log_error "Directory does not exist: ${parent_dir}"
    exit 1
  fi

  if ! formatter_available "${formatter_path}"; then
    log_error "Formatter not found or not executable: ${formatter_path}"
    exit 1
  fi

  note_path="$(build_note_path "${report_date}")"
  log_info "Target note path: ${note_path}"
  log_info "Report date: ${report_date}"
  log_info "Report timezone: ${timezone_name}"
  log_info "Repository root: ${parent_dir}"

  shopt -s nullglob

  for repo_path in "${parent_dir}"/*; do
    if [[ ! -d "${repo_path}" ]]; then
      continue
    fi

    process_repository "${formatter_path}" "${repo_path}" "${report_date}" "${timezone_name}" "${note_path}"
  done
}

main "$@"
