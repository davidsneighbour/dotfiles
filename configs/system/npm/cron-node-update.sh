#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PACKAGE_INSTALLER="${SCRIPT_DIR}/install-default-packages.ts"
DRY_RUN="false"
VERBOSE="false"

print_help() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} [--dry-run] [--verbose] [--help]

Install the latest Current Node.js release through NVM and set it as the
default version. If the resolved default version changes, install the default
global npm packages from configs/system/npm/default-packages.

Options:
  --dry-run   Print the commands that would run.
  --verbose   Print detailed progress.
  --help      Show this help.
EOF
}

log_info() {
  printf '[info] %s\n' "${*}"
}

log_verbose() {
  if [[ "${VERBOSE}" == "true" ]]; then
    printf '[debug] %s\n' "${*}"
  fi
}

log_error() {
  printf '[error] %s\n' "${*}" >&2
}

die() {
  log_error "${*}"
  exit 1
}

parse_args() {
  while (($# > 0)); do
    case "${1}" in
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      --verbose)
        VERBOSE="true"
        shift
        ;;
      --help)
        print_help
        exit 0
        ;;
      *)
        log_error "Unknown option: ${1}"
        print_help >&2
        exit 1
        ;;
    esac
  done
}

require_file() {
  local file_path="${1}"

  if [[ ! -f "${file_path}" ]]; then
    die "Required file not found: ${file_path}"
  fi
}

load_nvm() {
  export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
  log_verbose "Loading NVM from ${NVM_DIR}"

  if [[ ! -s "${NVM_DIR}/nvm.sh" ]]; then
    die "nvm.sh not found in ${NVM_DIR}"
  fi

  # shellcheck source=/dev/null
  . "${NVM_DIR}/nvm.sh"

  if ! command -v nvm >/dev/null 2>&1; then
    die "NVM did not load from ${NVM_DIR}/nvm.sh"
  fi
}

current_node_version() {
  node --version 2>/dev/null || printf '%s\n' 'none'
}

nvm_version_or_none() {
  local selector="${1}"
  local version=""

  if version="$(nvm version "${selector}" 2>/dev/null)" && [[ "${version}" != "N/A" ]]; then
    printf '%s\n' "${version}"
    return 0
  fi

  printf '%s\n' 'none'
}

print_command() {
  printf '[dry-run]'
  printf ' %q' "$@"
  printf '\n'
}

run_command() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    print_command "$@"
    return 0
  fi

  "$@"
}

install_latest_node() {
  local previous_active_version="${1}"
  local install_args

  install_args=(install --latest-npm)

  if [[ "${previous_active_version}" != "none" ]]; then
    install_args+=(--reinstall-packages-from=current)
  fi

  install_args+=(node)

  run_command nvm "${install_args[@]}"
}

install_default_packages() {
  run_command node --experimental-strip-types "${DEFAULT_PACKAGE_INSTALLER}" --quiet
}

main() {
  parse_args "$@"
  log_verbose "NPM config script directory: ${SCRIPT_DIR}"
  log_verbose "Default package installer: ${DEFAULT_PACKAGE_INSTALLER}"

  require_file "${DEFAULT_PACKAGE_INSTALLER}"
  load_nvm

  local previous_active_version
  local previous_default_version
  local current_default_version
  local current_active_version

  previous_active_version="$(current_node_version)"
  previous_default_version="$(nvm_version_or_none default)"

  log_info "Current Node.js: ${previous_active_version}"
  log_info "Current NVM default: ${previous_default_version}"
  log_info "Checking for latest Current Node.js release."

  install_latest_node "${previous_active_version}"
  run_command nvm alias default node
  run_command nvm use default

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Would install default packages only if the resolved default version changes."
    install_default_packages
    return 0
  fi

  current_default_version="$(nvm_version_or_none default)"
  current_active_version="$(current_node_version)"

  log_info "Node.js update check complete:"
  log_info "  active: ${previous_active_version} -> ${current_active_version}"
  log_info "  default: ${previous_default_version} -> ${current_default_version}"

  if [[ "${previous_default_version}" == "${current_default_version}" ]]; then
    log_info "Default Node.js version did not change; skipping default global npm packages."
    return 0
  fi

  log_info "Default Node.js version changed; installing default global npm packages."
  install_default_packages
}

main "$@"
