#!/bin/bash

readonly SCRIPT_NAME="${0##*/}"

usage() {
  cat <<USAGE
Usage:
  ${SCRIPT_NAME} lint [--verbose]
  ${SCRIPT_NAME} lint-all [--verbose]
  ${SCRIPT_NAME} format-check [--verbose]
  ${SCRIPT_NAME} format-write [--verbose]

Validate or format tracked Bash and shell files in this repository.

Commands:
  lint         Run ShellCheck errors against discovered shell files.
  lint-all     Run ShellCheck with its default severity.
  format-check Check shell formatting with shfmt.
  format-write Rewrite shell formatting with shfmt.

Options:
  --help       Show this help output.
  --verbose    Print the discovered file list before running.
USAGE
}

fail() {
  printf 'Error: %s\n\n' "${1}" >&2
  usage >&2
  exit 1
}

require_command() {
  local command_name="${1}"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    fail "Required command is not available: ${command_name}"
  fi
}

is_shell_file() {
  local file="${1}"
  local first_line

  case "${file}" in
    *.bash | *.sh | bashrc/.bash_profile | bashrc/.bashrc | bashrc/.bash_logout | bashrc/.profile)
      return 0
      ;;
    bashrc/lib/* | bashrc/partials/*)
      case "${file}" in
        *.md | *.json | *.toml)
          return 1
          ;;
        *) ;;
      esac
      return 0
      ;;
    *) ;;
  esac

  IFS= read -r first_line <"${file}" || first_line=''

  case "${first_line}" in
    '#!'*bash* | '#!'*'/sh'*)
      return 0
      ;;
    *) ;;
  esac

  return 1
}

discover_shell_files() {
  local candidates=()
  local file

  mapfile -d '' -t candidates < <(
    git ls-files -z -- \
      bashrc \
      configs/installs \
      configs/system/polybar/scripts \
      configs/system/rofi \
      scripts
  )

  SHELL_FILES=()

  for file in "${candidates[@]}"; do
    if [[ -f "${file}" ]] && is_shell_file "${file}"; then
      SHELL_FILES+=("${file}")
    fi
  done
}

print_files() {
  local file

  for file in "${SHELL_FILES[@]}"; do
    printf '%s\n' "${file}"
  done
}

run_lint() {
  local severity="${1}"

  require_command shellcheck
  discover_shell_files

  if [[ "${#SHELL_FILES[@]}" -eq 0 ]]; then
    fail 'No shell files were discovered.'
  fi

  if [[ "${VERBOSE}" == 'true' ]]; then
    print_files
  fi

  if [[ -n "${severity}" ]]; then
    shellcheck --shell=bash --severity="${severity}" "${SHELL_FILES[@]}"
  else
    shellcheck --shell=bash "${SHELL_FILES[@]}"
  fi
}

run_format_check() {
  require_command shfmt
  discover_shell_files

  if [[ "${#SHELL_FILES[@]}" -eq 0 ]]; then
    fail 'No shell files were discovered.'
  fi

  if [[ "${VERBOSE}" == 'true' ]]; then
    print_files
  fi

  shfmt -i 2 -ci -d "${SHELL_FILES[@]}"
}

run_format_write() {
  require_command shfmt
  discover_shell_files

  if [[ "${#SHELL_FILES[@]}" -eq 0 ]]; then
    fail 'No shell files were discovered.'
  fi

  if [[ "${VERBOSE}" == 'true' ]]; then
    print_files
  fi

  shfmt -i 2 -ci -w "${SHELL_FILES[@]}"
}

COMMAND=''
VERBOSE='false'
SHELL_FILES=()

while [[ "${#}" -gt 0 ]]; do
  case "${1}" in
    --help)
      usage
      exit 0
      ;;
    --verbose)
      VERBOSE='true'
      ;;
    lint | lint-all | format-check | format-write)
      if [[ -n "${COMMAND}" ]]; then
        fail 'Only one command can be provided.'
      fi
      COMMAND="${1}"
      ;;
    *)
      fail "Unknown argument: ${1}"
      ;;
  esac
  shift
done

if [[ -z "${COMMAND}" ]]; then
  fail 'A command is required.'
fi

case "${COMMAND}" in
  lint)
    run_lint error
    ;;
  lint-all)
    run_lint ''
    ;;
  format-check)
    run_format_check
    ;;
  format-write)
    run_format_write
    ;;
  *)
    fail "Unknown command: ${COMMAND}"
    ;;
esac
