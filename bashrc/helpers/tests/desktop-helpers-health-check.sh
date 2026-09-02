#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"

VERBOSE="0"

print_help() {
  cat <<'EOF'
Usage: desktop-helpers-health-check.sh [--verbose] [--help]

Smoke-check desktop helper scripts and local config references without
launching a desktop session.

Options:
  --verbose  Print non-fatal dependency warnings.
  --help     Show this help message.
EOF
}

fail() {
  printf 'FAIL: %s\n' "${1}" >&2
  exit 1
}

note() {
  if [[ "${VERBOSE}" == "1" ]]; then
    printf 'INFO: %s\n' "${1}"
  fi
}

warn() {
  if [[ "${VERBOSE}" == "1" ]]; then
    printf 'WARN: %s\n' "${1}" >&2
  fi
}

require_file() {
  local file_path="${1}"

  [[ -f "${file_path}" ]] || fail "Missing file: ${file_path}"
}

require_directory() {
  local directory_path="${1}"

  [[ -d "${directory_path}" ]] || fail "Missing directory: ${directory_path}"
}

require_executable() {
  local file_path="${1}"

  require_file "${file_path}"
  [[ -x "${file_path}" ]] || fail "File is not executable: ${file_path}"
}

check_optional_command() {
  local command_name="${1}"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    warn "Optional desktop command not found in PATH: ${command_name}"
  fi
}

check_shell_syntax() {
  local file_path
  local first_line

  while IFS= read -r -d '' file_path; do
    IFS= read -r first_line <"${file_path}" || first_line=""

    case "${first_line}" in
    "#!/bin/bash" | "#!/usr/bin/env bash" | "#!/usr/bin/env -S bash"*)
      note "bash -n ${file_path#"${REPO_ROOT}"/}"
      bash -n "${file_path}" || fail "Bash syntax failed: ${file_path}"
      ;;
    *)
      ;;
    esac
  done < <(
    find \
      "${REPO_ROOT}/configs/system/rofi" \
      "${REPO_ROOT}/configs/session/polybar/launch.sh" \
      "${REPO_ROOT}/configs/session/polybar/scripts" \
      -type f \
      -print0
  )

  bash -n "${REPO_ROOT}/configs/session/polybar/launch.sh" \
    || fail "Bash syntax failed: ${REPO_ROOT}/configs/session/polybar/launch.sh"
}

check_executable_entrypoints() {
  local file_path

  require_executable "${REPO_ROOT}/configs/session/polybar/launch.sh"

  while IFS= read -r -d '' file_path; do
    require_executable "${file_path}"
  done < <(
    find \
      "${REPO_ROOT}/configs/system/rofi" \
      "${REPO_ROOT}/configs/session/polybar/scripts" \
      -type f \
      \( -name '*.sh' -o -name 'polypomo' \) \
      -print0
  )

}

check_polybar_includes() {
  local config_file
  local include_directory
  local include_path

  while IFS= read -r config_file; do
    include_directory="${config_file#*=}"
    include_directory="${include_directory#"${include_directory%%[![:space:]]*}"}"
    include_directory="${include_directory%"${include_directory##*[![:space:]]}"}"
    include_path="${REPO_ROOT}/configs/session/polybar/${include_directory}"
    require_directory "${include_path}"
  done < <(
    grep -hE '^[[:space:]]*include-directory[[:space:]]*=' \
      "${REPO_ROOT}"/configs/session/polybar/*.ini
  )
}

check_rofi_imports() {
  local import_line
  local import_file
  local import_path
  local source_file

  while IFS=: read -r source_file import_line; do
    import_file="${import_line#*@import }"
    import_file="${import_file%\"}"
    import_file="${import_file#\"}"
    import_path="$(dirname "${source_file}")/${import_file}"
    if [[ -f "${import_path}" ]]; then
      continue
    fi
    require_file "${import_path}.rasi"
  done < <(
    grep -RE '^[[:space:]]*@import[[:space:]]+"[^"]+"' \
      "${REPO_ROOT}/configs/system/rofi"
  )
}

check_polybar_script_references() {
  local reference
  local script_name

  while IFS= read -r reference; do
    script_name="${reference##*/}"
    require_executable "${REPO_ROOT}/configs/session/polybar/scripts/${script_name}"
  done < <(
    grep -rhoE '[~]/.config/polybar/scripts/[[:alnum:]_.-]+' \
      "${REPO_ROOT}/configs/session/polybar/config.ini" \
      "${REPO_ROOT}/configs/session/polybar/configs" \
      | sort -u
  )
}

while [[ $# -gt 0 ]]; do
  case "${1}" in
  --verbose)
    VERBOSE="1"
    shift
    ;;
  --help)
    print_help
    exit 0
    ;;
  *)
    printf 'Error: unknown argument: %s\n\n' "${1}" >&2
    print_help >&2
    exit 1
    ;;
  esac
done

check_optional_command rofi
check_optional_command polybar
check_optional_command wmctrl
check_optional_command xdotool
check_optional_command xprop
check_optional_command xrandr
check_optional_command python3

check_shell_syntax
check_executable_entrypoints
check_polybar_includes
check_rofi_imports
check_polybar_script_references

printf 'PASS: desktop helper health check\n'
