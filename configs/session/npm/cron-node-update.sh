#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PACKAGE_INSTALLER="${SCRIPT_DIR}/install-default-packages.ts"
DRY_RUN="false"
VERBOSE="false"
UPDATE_LTS="false"

print_help() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} [--dry-run] [--lts] [--verbose] [--help]

Installs the latest stable Node.js release through NVM, migrates globally
installed npm packages from the active version, and sets it as the default.
Pre-releases (alpha, beta, rc, nightly) are skipped. If the resolved default version changes, install the default global npm
packages from configs/session/npm/default-packages.

Default global packages are installed only on hosts that opt in through the
\${NVM_DIR}/default-packages link (set up by the host-locutus Dotbot profile).
On other hosts the step is skipped.

Options:
  --lts       Install the latest LTS and refresh node-cron; keep the Current default.
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
      --lts)
        UPDATE_LTS="true"
        shift
        ;;
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

# Print the newest stable Node.js release known to NVM.
# The "node" alias follows the top of the Node.js release index, which now also
# carries pre-releases such as v27.0.0-alpha.0.0.0. Only plain vX.Y.Z versions
# qualify here, so alpha, beta, rc, and nightly builds are never selected.
latest_stable_node_version() {
  local listing=""
  local version=""
  local status=0

  # nvm ls-remote reads unset variables and exits with status 3 under set -u.
  set +u
  listing="$(nvm ls-remote --no-colors 2>/dev/null)" || status=$?
  set -u

  if ((status != 0)); then
    return 1
  fi

  version="$(printf '%s\n' "${listing}" | awk '
    {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/) {
          latest = $i
          break
        }
      }
    }
    END {
      if (latest != "") {
        print latest
      }
    }
  ')"

  if [[ -z "${version}" ]]; then
    return 1
  fi

  printf '%s\n' "${version}"
}

install_node_version() {
  local target_version="${1}"
  local previous_active_version="${2}"
  local install_args

  install_args=(install --latest-npm)

  if [[ "${previous_active_version}" != "none" ]]; then
    install_args+=(--reinstall-packages-from=current)
  fi

  install_args+=("${target_version}")

  run_command nvm "${install_args[@]}"
}

install_default_packages() {
  local opt_in_file="${NVM_DIR}/default-packages"

  if [[ ! -e "${opt_in_file}" ]]; then
    log_info "No ${opt_in_file} on this host; skipping default global npm packages."
    return 0
  fi

  run_command node --experimental-strip-types "${DEFAULT_PACKAGE_INSTALLER}" --quiet
}

main() {
  parse_args "$@"
  log_verbose "NPM config script directory: ${SCRIPT_DIR}"
  log_verbose "Default package installer: ${DEFAULT_PACKAGE_INSTALLER}"

  require_file "${DEFAULT_PACKAGE_INSTALLER}"
  load_nvm

  if [[ "${UPDATE_LTS}" == "true" ]]; then
    run_command /bin/bash "${SCRIPT_DIR}/../../../scripts/node-cron.sh" --update
    return 0
  fi

  local previous_active_version
  local previous_default_version
  local current_default_version
  local current_active_version

  previous_active_version="$(current_node_version)"
  previous_default_version="$(nvm_version_or_none default)"

  log_info "Node.js update started: $(date --iso-8601=seconds)"
  log_info "Current Node.js: ${previous_active_version}"
  log_info "Current NVM default: ${previous_default_version}"
  log_info "Checking for latest stable Current Node.js release."

  local target_version
  if ! target_version="$(latest_stable_node_version)"; then
    die "Could not resolve the latest stable Node.js release from nvm ls-remote."
  fi
  log_info "Latest stable Current Node.js: ${target_version}"

  install_node_version "${target_version}" "${previous_active_version}"
  run_command nvm alias default "${target_version}"
  run_command nvm use default

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Would install default packages only if the resolved default version changes."
    install_default_packages
    log_info "Node.js update completed: $(date --iso-8601=seconds)"
    return 0
  fi

  current_default_version="$(nvm_version_or_none default)"
  current_active_version="$(current_node_version)"

  log_info "Node.js update check complete:"
  log_info "  active: ${previous_active_version} -> ${current_active_version}"
  log_info "  default: ${previous_default_version} -> ${current_default_version}"

  if [[ "${previous_default_version}" == "${current_default_version}" ]]; then
    log_info "Default Node.js version did not change; skipping default global npm packages."
    log_info "Node.js update completed: $(date --iso-8601=seconds)"
    return 0
  fi

  log_info "Default Node.js version changed; installing default global npm packages."
  install_default_packages
  log_info "Node.js update completed: $(date --iso-8601=seconds)"
}

main "$@"
