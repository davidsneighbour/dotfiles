#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES_DIR="${DNB_DOTFILES_DIR:-$(cd "${SCRIPT_DIR}/../../.." && pwd -P)}"
LOG_DIR="${DNB_MSGVAULT_MANUAL_LOG_DIR:-${HOME}/.logs/msgvault}"
LOCK_FILE="${DNB_MSGVAULT_LOCK_FILE:-${HOME}/.logs/msgvault/msgvault.lock}"
MSGVAULT_BIN="${DNB_MSGVAULT_BIN:-${HOME}/.local/bin/msgvault}"
PAUSE_ON_EXIT="0"
VERBOSE="0"
LOG_FILE=""

usage() {
  cat <<USAGE
${SCRIPT_NAME} - run a visible manual msgvault sync

Usage:
  ${SCRIPT_NAME} [--msgvault-bin <path>] [--log-dir <path>] [--lock-file <path>] [--pause-on-exit] [--verbose]
  ${SCRIPT_NAME} --help

Options:
  --msgvault-bin <path>  msgvault executable path (default: ~/.local/bin/msgvault).
  --log-dir <path>      Manual log directory (default: ~/.logs/msgvault).
  --lock-file <path>    Shared msgvault lock file (default: ~/.logs/msgvault/msgvault.lock).
  --pause-on-exit       Wait for Enter before exiting, useful from Polybar terminals.
  --verbose             Print extra progress messages.
  --help                Show this help.
USAGE
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    --help)
      usage
      exit 0
      ;;
    --msgvault-bin)
      shift
      [[ "$#" -gt 0 ]] || {
        echo "ERROR: --msgvault-bin requires a value" >&2
        usage >&2
        exit 1
      }
      MSGVAULT_BIN="${1}"
      shift
      ;;
    --log-dir)
      shift
      [[ "$#" -gt 0 ]] || {
        echo "ERROR: --log-dir requires a value" >&2
        usage >&2
        exit 1
      }
      LOG_DIR="${1}"
      shift
      ;;
    --lock-file)
      shift
      [[ "$#" -gt 0 ]] || {
        echo "ERROR: --lock-file requires a value" >&2
        usage >&2
        exit 1
      }
      LOCK_FILE="${1}"
      shift
      ;;
    --pause-on-exit)
      PAUSE_ON_EXIT="1"
      shift
      ;;
    --verbose)
      VERBOSE="1"
      shift
      ;;
    *)
      echo "ERROR: Unknown option: ${1}" >&2
      usage >&2
      exit 1
      ;;
    esac
  done
}

source_libs() {
  local colors_lib="${DOTFILES_DIR}/bashrc/lib/00-core/dnb-core-colors.bash"
  local log_lib="${DOTFILES_DIR}/bashrc/lib/00-core/dnb-core-log.bash"

  if [[ ! -f "${colors_lib}" || ! -f "${log_lib}" ]]; then
    echo "ERROR: required logging libraries not found below ${DOTFILES_DIR}" >&2
    exit 1
  fi

  # shellcheck source=/dev/null
  source "${colors_lib}"
  # shellcheck source=/dev/null
  source "${log_lib}"
}

init_logging() {
  mkdir -p "${LOG_DIR}"
  DNB_SETUP_LOG_FILE="${LOG_DIR}/manual-$(date +%Y%m%d-%H%M).log"
  export DNB_SETUP_LOG_FILE
  LOG_FILE="$(dnb_log_init)"
}

log_verbose() {
  if [[ "${VERBOSE}" == "1" ]]; then
    dnb_log info "msgvault manual sync: ${*}"
  fi
}

pause_before_exit() {
  if [[ "${PAUSE_ON_EXIT}" != "1" || ! -t 0 ]]; then
    return 0
  fi

  printf '\nPress Enter to close this terminal... '
  if ! read -r; then
    printf '\n'
  fi
}

create_lock() {
  local started_at=""
  local host_name=""
  local lock_dir=""
  local attempt=""

  started_at="$(date --iso-8601=seconds)"
  host_name="$(hostname 2>/dev/null || echo "unknown")"
  lock_dir="$(dirname "${LOCK_FILE}")"

  mkdir -p "${lock_dir}"

  for attempt in 1 2; do
    if (
      set -o noclobber
      {
        echo "started_at=${started_at}"
        echo "pid=$$"
        echo "host=${host_name}"
        echo "log_file=${LOG_FILE}"
        echo "mode=manual"
      } >"${LOCK_FILE}"
    ) 2>/dev/null; then
      return 0
    fi

    if [[ "${attempt}" == "1" ]] && remove_stale_lock; then
      continue
    fi

    dnb_log warn "another msgvault sync is already running; lock file exists: ${LOCK_FILE}"
    if [[ -f "${LOCK_FILE}" ]]; then
      {
        echo
        echo "Existing lock content:"
        sed 's/^/  /' "${LOCK_FILE}" 2>/dev/null || echo "  Could not read lock file."
      } | tee -a "${LOG_FILE}"
    fi
    return 1
  done

  return 1
}

cleanup_lock() {
  if [[ -f "${LOCK_FILE}" ]] && grep -qx "pid=$$" "${LOCK_FILE}" 2>/dev/null; then
    rm -f "${LOCK_FILE}"
  fi
}

lock_value() {
  local key="${1}"

  awk -F= -v key="${key}" '$1 == key { print $2; exit }' "${LOCK_FILE}" 2>/dev/null
}

lock_is_active() {
  local lock_pid=""
  local lock_host=""
  local current_host=""
  local lock_cmdline=""

  [[ -f "${LOCK_FILE}" ]] || return 1

  lock_pid="$(lock_value "pid")"
  lock_host="$(lock_value "host")"
  current_host="$(hostname 2>/dev/null || echo "unknown")"

  if [[ -n "${lock_host}" && "${lock_host}" != "${current_host}" ]]; then
    return 0
  fi

  if [[ ! "${lock_pid}" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  kill -0 "${lock_pid}" 2>/dev/null || return 1

  if [[ -r "/proc/${lock_pid}/cmdline" ]]; then
    lock_cmdline="$(tr '\0' ' ' <"/proc/${lock_pid}/cmdline" 2>/dev/null || echo "")"
    case "${lock_cmdline}" in
    *msgvault/sync.sh* | *msgvault/manual-sync.sh* | *msgvault.sh* | *msgvault-manual-sync.sh*)
      return 0
      ;;
    *)
      return 1
      ;;
    esac
  fi

  return 0
}

remove_stale_lock() {
  [[ -f "${LOCK_FILE}" ]] || return 1

  if lock_is_active; then
    return 1
  fi

  dnb_log warn "removing stale msgvault lock file: ${LOCK_FILE}"
  {
    echo
    echo "Previous lock content:"
    sed 's/^/  /' "${LOCK_FILE}" 2>/dev/null || echo "  Could not read lock file."
  } | tee -a "${LOG_FILE}"

  rm -f "${LOCK_FILE}"
}

abort_run() {
  local exit_code="${1:-143}"

  dnb_log warn "msgvault manual sync interrupted"
  cleanup_lock
  exit "${exit_code}"
}

run_msgvault_sync() {
  local command_line=""
  local sync_exit_code="0"

  printf -v command_line "%q sync --verbose" "${MSGVAULT_BIN}"

  if command -v script >/dev/null 2>&1; then
    script --quiet --append --return --command "${command_line}" "${LOG_FILE}"
    return "$?"
  fi

  dnb_log warn "script command not found; falling back to tee logging without a pseudo-terminal"
  "${MSGVAULT_BIN}" sync --verbose 2>&1 | tee -a "${LOG_FILE}"
  sync_exit_code="${PIPESTATUS[0]}"
  return "${sync_exit_code}"
}

main() {
  local sync_exit_code="0"

  parse_args "$@"
  source_libs
  init_logging

  dnb_log info "Manual msgvault sync requested"
  dnb_log info "Log file: ${LOG_FILE}"

  if [[ ! -x "${MSGVAULT_BIN}" ]]; then
    dnb_log error "msgvault binary not found or not executable: ${MSGVAULT_BIN}"
    pause_before_exit
    exit 1
  fi

  if ! create_lock; then
    pause_before_exit
    exit 0
  fi

  trap cleanup_lock EXIT
  trap 'abort_run 129' HUP
  trap 'abort_run 130' INT
  trap 'abort_run 143' TERM

  log_verbose "running ${MSGVAULT_BIN} sync --verbose"
  if run_msgvault_sync; then
    sync_exit_code="0"
  else
    sync_exit_code="$?"
  fi

  if [[ "${sync_exit_code}" -ne 0 ]]; then
    dnb_log error "msgvault sync failed with exit code ${sync_exit_code}"
    pause_before_exit
    exit "${sync_exit_code}"
  fi

  dnb_log success "msgvault sync finished successfully"
  pause_before_exit
}

main "$@"
