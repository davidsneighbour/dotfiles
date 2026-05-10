#!/bin/bash
# Create a zip archive from one or more package definitions in config files.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "${0}")"
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH='' cd -- "${SCRIPT_DIR}/../../.." && pwd)"
LOG_CONTEXT='packages/create'
QUIET_MODE='false'
PACKAGE_NAME=''
OUTPUT_DIR="${PWD}"
CONFIG_FILES_SOURCE='default'

# Load the repository logging API when the helper is run as a standalone command.
BASHRC_PATH="${REPO_ROOT}/bashrc"
for FILE in "${BASHRC_PATH}"/lib/*/*.bash; do
  # shellcheck disable=SC1090
  [[ -f "${FILE}" && -r "${FILE}" ]] && source "${FILE}"
done

usage() {
  cat <<EOF_USAGE
Usage:
  ${SCRIPT_NAME} --package <name> [--config <file> ...] [--output-dir <dir>] [--verbose|--quiet]
  ${SCRIPT_NAME} --list [--config <file> ...] [--verbose|--quiet]
  ${SCRIPT_NAME} --help

Create a zip archive from a named [packages.<name>] section.

Required for archive creation:
  --package <name>          Package section name to archive.

Configuration:
  --config <file>           Read package definitions from this config file. May be repeated.
                            CLI config files override DNB_PACKAGE_CONFIG_FILES.
  DNB_PACKAGE_CONFIG_FILES  Colon-separated config file list used when --config is omitted.
                            Default: ~/.dotfiles/configs/hosts/<hostname-lowercase>.toml

Archive output:
  --output-dir <dir>        Directory where the zip file is created. Default: current directory.

Verbosity:
  --verbose                 Enable verbose logging and export DNB_VERBOSE=1 for child commands.
  --quiet                   Disable verbose output and unset DNB_VERBOSE. Overrides --verbose.
  DNB_VERBOSE=1             Enable verbose logging when --quiet is not used.

Other options:
  --list                    List package names found in the selected config files.
  --help                    Show this help.

Config syntax:
  [packages.example]
  ~/Documents/report.pdf
  \$HOME/Pictures/*.png
  /srv/project/releases/**/*.tar.gz

Path syntax:
  * Paths are one per line under a [packages.<name>] header.
  * Empty lines and lines starting with # or ; are ignored.
  * Use ~ or \$HOME for the home directory.
  * Other \$VARIABLE references are expanded when envsubst is available.
  * Use Bash glob patterns directly in path lines: *, ?, [...], and **.
  * ** matches recursively when it appears in a glob pattern.
  * Quote glob patterns when passing them through a shell, but do not quote them in the config file.
  * Filename newline characters are not supported.

Examples:
  ${SCRIPT_NAME} --package documents
  ${SCRIPT_NAME} --package photos --config ~/.config/dnb/packages.toml --verbose
  DNB_PACKAGE_CONFIG_FILES="~/.config/dnb/packages.toml:/etc/dnb/packages.toml" ${SCRIPT_NAME} --list
EOF_USAGE
}

init_verbose_logging() {
  local log_dir="${HOME}/.logs/${LOG_CONTEXT}"

  if [[ -z "${DNB_SETUP_LOG_FILE:-}" ]]; then
    DNB_SETUP_LOG_FILE="${log_dir}/setup-log-$(date +%Y%m%d-%H%M%S).log"
    export DNB_SETUP_LOG_FILE
  fi

  dnb_create_directory "${log_dir}" >/dev/null
  dnb_log_init >/dev/null
}

log_verbose() {
  if [[ "${DNB_VERBOSE:-}" == '1' ]]; then
    dnb_log info "${LOG_CONTEXT}: ${*}"
  fi
}

print_error() {
  printf 'ERROR: %s\n' "${*}" >&2
  if [[ "${DNB_VERBOSE:-}" == '1' ]]; then
    if [[ -z "${DNB_SETUP_LOG_FILE:-}" ]]; then
      init_verbose_logging
    fi
    dnb_error "${LOG_CONTEXT}: ${*}"
  fi
}

die() {
  print_error "${1}"
  printf '\n' >&2
  usage >&2
  exit "${2:-1}"
}


hostname_lc() {
  local host_name=''

  if ! host_name="$(hostname 2>/dev/null)"; then
    die 'Unable to determine hostname for the default config file.' 1
  fi

  if [[ -z "${host_name}" ]]; then
    die 'Hostname is empty; cannot determine the default config file.' 1
  fi

  printf '%s' "${host_name}" | tr '[:upper:]' '[:lower:]'
}

default_config_file() {
  local host_name=''
  host_name="$(hostname_lc)"
  printf '%s/.dotfiles/configs/hosts/%s.toml' "${HOME}" "${host_name}"
}

add_config_file() {
  local raw_path="${1}"
  local expanded_path=''

  if [[ -z "${raw_path}" ]]; then
    die 'Config file path must not be empty.' 2
  fi

  expanded_path="$(dnb_path_expand "${raw_path}")"
  CONFIG_FILES+=("${expanded_path}")
}

load_env_config_files() {
  local raw_files="${DNB_PACKAGE_CONFIG_FILES:-}"
  local raw_file=''

  if [[ -z "${raw_files}" ]]; then
    return 1
  fi

  while IFS= read -r raw_file; do
    add_config_file "${raw_file}"
  done < <(printf '%s\n' "${raw_files}" | tr ':' '\n')

  CONFIG_FILES_SOURCE='DNB_PACKAGE_CONFIG_FILES'
  return 0
}

ensure_config_files() {
  local config_file=''

  if [[ "${#CONFIG_FILES[@]}" -eq 0 ]]; then
    if ! load_env_config_files; then
      add_config_file "$(default_config_file)"
      CONFIG_FILES_SOURCE='default'
    fi
  fi

  for config_file in "${CONFIG_FILES[@]}"; do
    if [[ ! -f "${config_file}" ]]; then
      die "Config file not found: ${config_file}" 1
    fi
    if [[ ! -r "${config_file}" ]]; then
      die "Config file is not readable: ${config_file}" 1
    fi
  done
}

list_packages() {
  local config_file=''

  for config_file in "${CONFIG_FILES[@]}"; do
    dnb_package_list_sections "${config_file}"
  done | sort -u
}


package_exists() {
  local candidate=''

  while IFS= read -r candidate; do
    if [[ "${candidate}" == "${PACKAGE_NAME}" ]]; then
      return 0
    fi
  done < <(list_packages)

  return 1
}

resolve_package_path() {
  local expanded_path="${1}"
  local matched_path=''
  local resolved='false'

  while IFS= read -r matched_path; do
    if [[ -n "${matched_path}" ]]; then
      RESOLVED_PATHS+=("${matched_path}")
      resolved='true'
    fi
  done < <(dnb_path_resolve_pattern "${expanded_path}")

  if [[ "${resolved}" == 'false' ]]; then
    MISSING_PATHS+=("${expanded_path}")
  fi
}


read_and_resolve_package_paths() {
  local config_file=''
  local raw_path=''
  local expanded_path=''
  local raw_count=0

  for config_file in "${CONFIG_FILES[@]}"; do
    while IFS= read -r raw_path; do
      raw_count=$((raw_count + 1))
      expanded_path="$(dnb_path_expand "${raw_path}")"
      log_verbose "path '${raw_path}' expanded to '${expanded_path}'"
      resolve_package_path "${expanded_path}"
    done < <(dnb_package_read_paths "${config_file}" "${PACKAGE_NAME}")
  done

  if [[ "${raw_count}" -eq 0 ]]; then
    die "Package '${PACKAGE_NAME}' exists but contains no paths." 1
  fi
}

make_zip_name() {
  local package_name="${1}"
  local timestamp=''

  timestamp="$(date +'%Y%m%d%H%M')"
  printf '%s-%s.zip' "${package_name}" "${timestamp}"
}

parse_args() {
  local saw_cli_config='false'

  if [[ "${#}" -eq 0 ]]; then
    usage
    exit 2
  fi

  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
      --help|-h)
        usage
        exit 0
        ;;
      --verbose)
        export DNB_VERBOSE='1'
        shift
        ;;
      --quiet)
        QUIET_MODE='true'
        shift
        ;;
      --package)
        if [[ -z "${2:-}" ]]; then
          die '--package requires a value.' 2
        fi
        PACKAGE_NAME="${2}"
        shift 2
        ;;
      --config)
        if [[ -z "${2:-}" ]]; then
          die '--config requires a file path.' 2
        fi
        if [[ "${saw_cli_config}" == 'false' ]]; then
          CONFIG_FILES=()
          saw_cli_config='true'
          CONFIG_FILES_SOURCE='--config'
        fi
        add_config_file "${2}"
        shift 2
        ;;
      --output-dir)
        if [[ -z "${2:-}" ]]; then
          die '--output-dir requires a directory path.' 2
        fi
        OUTPUT_DIR="$(dnb_path_expand "${2}")"
        shift 2
        ;;
      --list)
        LIST_ONLY='true'
        shift
        ;;
      --*)
        die "Unknown option: ${1}" 2
        ;;
      *)
        die "Unexpected positional argument: ${1}. Use --package <name>." 2
        ;;
    esac
  done

  if [[ "${QUIET_MODE}" == 'true' ]]; then
    unset DNB_VERBOSE
  fi
}

main() {
  local output_file=''
  local package_list=''

  CONFIG_FILES=()
  RESOLVED_PATHS=()
  MISSING_PATHS=()
  LIST_ONLY='false'

  parse_args "$@"

  if [[ "${DNB_VERBOSE:-}" == '1' ]]; then
    init_verbose_logging
    log_verbose 'Verbose logging enabled'
  fi

  ensure_config_files
  log_verbose "Config source: ${CONFIG_FILES_SOURCE}"
  log_verbose "Config files: ${CONFIG_FILES[*]}"

  if [[ "${LIST_ONLY}" == 'true' ]]; then
    package_list="$(list_packages)"
    if [[ -z "${package_list}" ]]; then
      die "No package definitions found in selected config files." 1
    fi
    printf '%s\n' "${package_list}"
    exit 0
  fi

  if [[ -z "${PACKAGE_NAME}" ]]; then
    die 'Missing required --package <name>.' 2
  fi

  if ! dnb_check_requirements 'zip'; then
    die "Missing required command: zip" 1
  fi

  if [[ ! -d "${OUTPUT_DIR}" ]]; then
    die "Output directory not found: ${OUTPUT_DIR}" 1
  fi

  if ! package_exists; then
    printf 'ERROR: Package %s is not defined in selected config files.\n\n' "'${PACKAGE_NAME}'" >&2
    printf 'Defined packages:\n' >&2
    list_packages | sed 's/^/  - /' >&2
    exit 1
  fi

  read_and_resolve_package_paths

  if [[ "${#MISSING_PATHS[@]}" -gt 0 ]]; then
    printf 'ERROR: Some configured paths did not exist or glob patterns did not match. Aborting.\n' >&2
    printf 'Missing paths or unmatched globs:\n' >&2
    printf '  - %s\n' "${MISSING_PATHS[@]}" >&2
    exit 1
  fi

  if [[ "${#RESOLVED_PATHS[@]}" -eq 0 ]]; then
    die "Package '${PACKAGE_NAME}' did not resolve to any archive items." 1
  fi

  output_file="${OUTPUT_DIR}/$(make_zip_name "${PACKAGE_NAME}")"

  log_verbose "Package: ${PACKAGE_NAME}"
  log_verbose "Output: ${output_file}"
  log_verbose "Resolved items: ${RESOLVED_PATHS[*]}"

  zip -r "${output_file}" "${RESOLVED_PATHS[@]}" >/dev/null

  printf '%s\n' "${output_file}"
  log_verbose "Created archive: ${output_file}"
}

main "$@"
