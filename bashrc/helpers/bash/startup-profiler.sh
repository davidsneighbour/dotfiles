#!/bin/bash

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_LOG_DIR="${HOME}/.logs"
readonly DEFAULT_TRACE_FILE="${DEFAULT_LOG_DIR}/bash-startup-trace.log"
readonly DEFAULT_REPORT_FILE="${DEFAULT_LOG_DIR}/bash-startup-report.tsv"

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Profile Bash interactive startup time and generate a readable timing report.

Options:
  --trace-file FILE     Write raw Bash trace output to FILE.
                        Default: ${DEFAULT_TRACE_FILE}

  --report-file FILE    Write timing report to FILE.
                        Default: ${DEFAULT_REPORT_FILE}

  --top NUMBER          Show the slowest NUMBER trace steps.
                        Default: 100

  --login              Profile a login shell instead of a normal interactive shell.

  --keep-trace          Keep the raw trace file.
                        By default, the trace file is kept anyway, but this option is
                        provided for explicitness.

  --help               Show this help message.

Examples:
  ${SCRIPT_NAME}

  ${SCRIPT_NAME} --top 50

  ${SCRIPT_NAME} --login

  ${SCRIPT_NAME} --trace-file "\${HOME}/.logs/bash-login-trace.log" \\
    --report-file "\${HOME}/.logs/bash-login-report.tsv" \\
    --login

Output:
  The report is a tab-separated file with these columns:

  seconds
  file
  line
  command

Notes:
  This profiles Bash startup by launching a temporary interactive Bash shell
  and immediately exiting it.

  The raw trace can be noisy, but it shows exactly which startup lines Bash ran.

  The timing is measured between consecutive traced commands. A slow line may
  sometimes mean that the previous command took time before the next trace line
  appeared.
EOF
}

fail() {
  local message="${1:-Unknown error}"
  printf '[error] %s\n' "${message}" >&2
  exit 1
}

ensure_log_dir() {
  local file_path="${1}"

  local directory
  directory="$(dirname "${file_path}")"

  if [[ ! -d "${directory}" ]]; then
    mkdir -p "${directory}"
  fi
}

run_trace() {
  local trace_file="${1}"
  local login_mode="${2}"

  ensure_log_dir "${trace_file}"

  if [[ "${login_mode}" == "yes" ]]; then
    PS4='+ ${EPOCHREALTIME} ${BASH_SOURCE}:${LINENO}: ' \
      bash --login -x -i -c 'exit' 2>"${trace_file}"
  else
    PS4='+ ${EPOCHREALTIME} ${BASH_SOURCE}:${LINENO}: ' \
      bash -x -i -c 'exit' 2>"${trace_file}"
  fi
}

generate_report() {
  local trace_file="${1}"
  local report_file="${2}"

  ensure_log_dir "${report_file}"

  awk '
    BEGIN {
      previous_timestamp = "";
      previous_file = "";
      previous_line = "";
      previous_command = "";
      OFS = "\t";
      print "seconds", "file", "line", "command";
    }

    /^\+ [0-9]+\.[0-9]+ / {
      timestamp = $2;

      rest = $0;
      sub(/^\+ [0-9]+\.[0-9]+ /, "", rest);

      location = rest;
      sub(/: .*/, "", location);

      command = rest;
      sub(/^[^:]+:[0-9]+: /, "", command);

      file = location;
      line = location;

      sub(/:[0-9]+$/, "", file);
      sub(/^.*:/, "", line);

      if (previous_timestamp != "") {
        duration = timestamp - previous_timestamp;

        if (duration > 0) {
          print duration, previous_file, previous_line, previous_command;
        }
      }

      previous_timestamp = timestamp;
      previous_file = file;
      previous_line = line;
      previous_command = command;
    }
  ' "${trace_file}" >"${report_file}"
}

print_top_results() {
  local report_file="${1}"
  local top_count="${2}"

  printf '\nSlowest startup trace steps:\n\n'

  tail -n +2 "${report_file}" |
    sort -nr -k1,1 |
    head -n "${top_count}" |
    awk -F '\t' '
      {
        printf "%8.4fs  %s:%s  %s\n", $1, $2, $3, $4
      }
    '
}

main() {
  local trace_file="${DEFAULT_TRACE_FILE}"
  local report_file="${DEFAULT_REPORT_FILE}"
  local top_count="30"
  local login_mode="no"

  if [[ "$#" -eq 0 ]]; then
    :
  fi

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    --trace-file)
      [[ "$#" -ge 2 ]] || fail "Missing value for --trace-file."
      trace_file="${2}"
      shift 2
      ;;
    --report-file)
      [[ "$#" -ge 2 ]] || fail "Missing value for --report-file."
      report_file="${2}"
      shift 2
      ;;
    --top)
      [[ "$#" -ge 2 ]] || fail "Missing value for --top."
      top_count="${2}"
      shift 2
      ;;
    --login)
      login_mode="yes"
      shift
      ;;
    --keep-trace)
      shift
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      printf '[error] Unknown option: %s\n\n' "${1}" >&2
      print_help >&2
      exit 1
      ;;
    esac
  done

  [[ "${top_count}" =~ ^[0-9]+$ ]] || fail "--top must be a positive integer."

  run_trace "${trace_file}" "${login_mode}"
  generate_report "${trace_file}" "${report_file}"
  print_top_results "${report_file}" "${top_count}"

  printf '\nRaw trace: %s\n' "${trace_file}"
  printf 'Report:    %s\n' "${report_file}"
}

main "$@"
