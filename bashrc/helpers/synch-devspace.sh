#!/bin/bash

# sync-devspace.sh
#
# Synchronise a local repository root such as ~/github.com/ to a second
# workstation using rsync, preserving Git metadata including .git/hooks/.
#
# Features:
# * dry-run support
# * verbose output
# * optional delete on target
# * optional SSH transport
# * excludes common generated folders
# * keeps .git/ content, including hooks
#
# Requirements:
# * bash
# * rsync
# * ssh (only when syncing to a remote host)
#
# Examples:
#   ./sync-devspace.sh --target /mnt/backup/github.com
#   ./sync-devspace.sh --source "${HOME}/github.com" --target patrick@ws2:/home/patrick/github.com
#   ./sync-devspace.sh --target patrick@ws2:/home/patrick/github.com --delete
#   ./sync-devspace.sh --target patrick@ws2:/home/patrick/github.com --dry-run --verbose

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.0.2"

DEFAULT_SOURCE="${HOME}/github.com"
DEFAULT_DELETE="false"
DEFAULT_DRY_RUN="false"
DEFAULT_VERBOSE="false"
DEFAULT_EXCLUDE_FILE=""
DEFAULT_SSH_PORT=""
DEFAULT_COMPRESS="true"

print_usage() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} --target <path|user@host:path> [options]

Description:
  Synchronise a Git repository root to another workstation using rsync.
  The directory structure is preserved exactly. Git repositories remain usable
  because the full '.git/' directories are copied, including '.git/hooks/'.

Required options:
  --target <path|user@host:path>
      Destination root. Examples:
      * /mnt/workstation-sync/github.com
      * patrick@ws2:/home/patrick/github.com

Optional options:
  --source <path>
      Source root (default: ${DEFAULT_SOURCE})

  --delete
      Delete files on the target that do not exist on the source.

  --dry-run
      Show what would change without modifying anything.

  --verbose
      Print more detailed output.

  --exclude-file <path>
      Additional rsync exclude file. One pattern per line.

  --ssh-port <port>
      SSH port for remote targets.

  --no-compress
      Disable rsync compression for remote transfers.

  --help
      Show this help text.

  --version
      Show script version.

Notes:
  * '.git/hooks/' is intentionally included.
  * Common generated folders like 'node_modules/', 'dist/', and '.cache/'
    are excluded by default.
  * This script assumes compatible Linux filesystems.

EOF
}

print_version() {
  printf '%s %s\n' "${SCRIPT_NAME}" "${VERSION}"
}

print_info() {
  printf 'INFO %s\n' "$1"
}

print_warn() {
  printf 'WARN %s\n' "$1" >&2
}

print_error() {
  printf 'ERROR %s\n' "$1" >&2
}

print_debug() {
  if [[ "${VERBOSE}" == "true" ]]; then
    printf 'DEBUG %s\n' "$1"
  fi
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    print_error "Required command not found: ${command_name}"
    exit 1
  fi
}

is_remote_target() {
  local target_value="$1"

  [[ "${target_value}" =~ ^[^:/]+@[^:/]+:.+$ ]]
}

ensure_directory_exists() {
  local path_value="$1"

  if [[ ! -d "${path_value}" ]]; then
    print_error "Directory does not exist: ${path_value}"
    exit 1
  fi
}

create_temp_exclude_file() {
  TEMP_EXCLUDE_FILE="$(mktemp)"

  cat > "${TEMP_EXCLUDE_FILE}" <<'EOF'
node_modules/
dist/
build/
coverage/
.cache/
.parcel-cache/
.next/
.nuxt/
.svelte-kit/
.astro/
.tmp/
temp/
__pycache__/
.python-version
.pytest_cache/
.mypy_cache/
.ruff_cache/
.venv/
venv/
.envrc
.DS_Store
Thumbs.db
EOF
}

cleanup() {
  if [[ -n "${TEMP_EXCLUDE_FILE:-}" && -f "${TEMP_EXCLUDE_FILE}" ]]; then
    rm -f "${TEMP_EXCLUDE_FILE}"
  fi
}

build_rsync_command() {
  RSYNC_ARGS=(
    -aHAX
    --human-readable
    --partial
    --info=stats2,progress2
  )

  if [[ "${VERBOSE}" == "true" ]]; then
    RSYNC_ARGS+=(-v)
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    RSYNC_ARGS+=(--dry-run)
  fi

  if [[ "${DELETE}" == "true" ]]; then
    RSYNC_ARGS+=(--delete --delete-delay)
  fi

  if [[ -n "${TEMP_EXCLUDE_FILE}" ]]; then
    RSYNC_ARGS+=(--exclude-from="${TEMP_EXCLUDE_FILE}")
  fi

  if [[ -n "${EXCLUDE_FILE}" ]]; then
    RSYNC_ARGS+=(--exclude-from="${EXCLUDE_FILE}")
  fi

  if is_remote_target "${TARGET}"; then
    local ssh_command="ssh"

    if [[ -n "${SSH_PORT}" ]]; then
      ssh_command+=" -p ${SSH_PORT}"
    fi

    RSYNC_ARGS+=(-e "${ssh_command}")

    if [[ "${COMPRESS}" == "true" ]]; then
      RSYNC_ARGS+=(-z)
    fi
  fi

  RSYNC_ARGS+=("${SOURCE}/" "${TARGET}/")
}

validate_arguments() {
  if [[ -z "${TARGET}" ]]; then
    print_error "Missing required option: --target"
    print_usage
    exit 1
  fi

  ensure_directory_exists "${SOURCE}"

  if [[ -n "${EXCLUDE_FILE}" && ! -f "${EXCLUDE_FILE}" ]]; then
    print_error "Exclude file does not exist: ${EXCLUDE_FILE}"
    exit 1
  fi
}

show_summary() {
  print_info "Source: ${SOURCE}"
  print_info "Target: ${TARGET}"
  print_info "Delete mode: ${DELETE}"
  print_info "Dry-run mode: ${DRY_RUN}"
  print_info "Verbose mode: ${VERBOSE}"
  print_info "Compression: ${COMPRESS}"
  print_info ".git/hooks: included"

  if [[ -n "${EXCLUDE_FILE}" ]]; then
    print_info "Additional exclude file: ${EXCLUDE_FILE}"
  fi

  if [[ -n "${SSH_PORT}" ]]; then
    print_info "SSH port: ${SSH_PORT}"
  fi
}

parse_arguments() {
  SOURCE="${DEFAULT_SOURCE}"
  TARGET=""
  DELETE="${DEFAULT_DELETE}"
  DRY_RUN="${DEFAULT_DRY_RUN}"
  VERBOSE="${DEFAULT_VERBOSE}"
  EXCLUDE_FILE="${DEFAULT_EXCLUDE_FILE}"
  SSH_PORT="${DEFAULT_SSH_PORT}"
  COMPRESS="${DEFAULT_COMPRESS}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)
        if [[ $# -lt 2 ]]; then
          print_error "Missing value for --source"
          print_usage
          exit 1
        fi
        SOURCE="$2"
        shift 2
        ;;
      --target)
        if [[ $# -lt 2 ]]; then
          print_error "Missing value for --target"
          print_usage
          exit 1
        fi
        TARGET="$2"
        shift 2
        ;;
      --delete)
        DELETE="true"
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
      --exclude-file)
        if [[ $# -lt 2 ]]; then
          print_error "Missing value for --exclude-file"
          print_usage
          exit 1
        fi
        EXCLUDE_FILE="$2"
        shift 2
        ;;
      --ssh-port)
        if [[ $# -lt 2 ]]; then
          print_error "Missing value for --ssh-port"
          print_usage
          exit 1
        fi
        SSH_PORT="$2"
        shift 2
        ;;
      --no-compress)
        COMPRESS="false"
        shift
        ;;
      --help)
        print_usage
        exit 0
        ;;
      --version)
        print_version
        exit 0
        ;;
      *)
        print_error "Unknown option: $1"
        print_usage
        exit 1
        ;;
    esac
  done
}

get_remote_connection_parts() {
  REMOTE_SSH_HOST="${TARGET%%:*}"
  REMOTE_PATH="${TARGET#*:}"
}

run_remote_github_check() {
  local ssh_command=(ssh)
  local remote_output=""
  local remote_status=0

  if [[ -n "${SSH_PORT}" ]]; then
    ssh_command+=(-p "${SSH_PORT}")
  fi

  get_remote_connection_parts

  print_info "Running GitHub SSH check on remote host: ${REMOTE_SSH_HOST}"

  set +e
  remote_output="$("${ssh_command[@]}" "${REMOTE_SSH_HOST}" 'ssh -T git@github.com' 2>&1)"
  remote_status=$?
  set -e

  printf '%s\n' "${remote_output}"

  if printf '%s\n' "${remote_output}" | grep -qi 'successfully authenticated'; then
    print_info "Remote GitHub SSH authentication looks OK."
    return 0
  fi

  if [[ ${remote_status} -eq 1 ]] && printf '%s\n' "${remote_output}" | grep -qi 'successfully authenticated'; then
    print_info "Remote GitHub SSH authentication looks OK."
    return 0
  fi

  print_warn "Remote GitHub SSH check did not return the expected authentication message."
  return 1
}

post_checks() {
  if is_remote_target "${TARGET}"; then
    run_remote_github_check
  fi
}

main() {
  require_command rsync
  parse_arguments "$@"
  validate_arguments

  if is_remote_target "${TARGET}"; then
    require_command ssh
  fi

  trap cleanup EXIT
  create_temp_exclude_file
  build_rsync_command
  show_summary

  if [[ "${VERBOSE}" == "true" ]]; then
    print_debug "Running rsync command:"
    printf 'DEBUG %q ' rsync "${RSYNC_ARGS[@]}"
    printf '\n'
  fi

  rsync "${RSYNC_ARGS[@]}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    print_info "Dry-run completed."
  else
    print_info "Sync completed."
  fi

  post_checks
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [[ $# -eq 0 ]]; then
    print_usage
    exit 1
  fi

  main "$@"
fi
