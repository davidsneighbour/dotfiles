#!/bin/bash

# load the library functions
for FILE in "${BASHRC_PATH}"/lib/*/*.bash; do
  # shellcheck disable=SC1090
  [[ -f "${FILE}" && -r "${FILE}" ]] && source "${FILE}"
done

ws_init_logging() {
  local log_path="${1:-workspaces/general}"
  LOG_PATH="${log_path}"
  LOG_FILE="${HOME}/.logs/${LOG_PATH}/$(date +'%Y%m%d-%H%M%S').log"
  mkdir -p "$(dirname "${LOG_FILE}")"
  export __LOGFILE="${LOG_FILE}"
}

ws_parse_verbosity_flag() {
  local arg="${1}"
  case "${arg}" in
  --verbose)
    export DNB_VERBOSE=1
    return 0
    ;;
  --quiet)
    unset DNB_VERBOSE
    WS_QUIET_MODE=1
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

ws_log_verbose() {
  if [[ "${DNB_VERBOSE:-}" == "1" ]]; then
    __dnb_log "${1}" info
  fi
}

ws_log_error() {
  __dnb_log "${1}" error
}
