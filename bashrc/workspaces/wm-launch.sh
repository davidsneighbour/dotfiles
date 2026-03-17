#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${HOME}/.logs/workspaces"
LOG_FILE=""
VERBOSE="0"
WORKSPACE_NUM=""
TILE_TEMPLATE=""
EXEC_COMMAND=""
SWITCH_WORKSPACE="0"

usage() {
  cat <<EOF_USAGE
${SCRIPT_NAME} [--workspace N] [--tile TEMPLATE] [--switch|--no-switch] [--verbose] --exec "command"

Launch a program on a workspace and optionally apply a tile template.

Options:
  --exec COMMAND
      Command to launch. Required.
      Use quotes when passing CLI args, for example:
      --exec "google-chrome --new-window https://example.com"

  --workspace N
      Workspace number (1-based). Optional. Default: current workspace.

  --tile TEMPLATE
      Tile template from ${SCRIPT_DIR}/config.toml. Optional.
      If omitted, no tiling is applied.

  --switch
      Visually switch to the target workspace before launching the program.

  --no-switch
      Do not visually switch to the target workspace before launching the program.
      Default.

  --verbose
      Print debug logs to stderr.

  --help
      Show this help.

Examples:
  ${SCRIPT_NAME} --exec "code"
  ${SCRIPT_NAME} --workspace 3 --exec "obsidian"
  ${SCRIPT_NAME} --workspace 2 --tile right-half --exec "google-chrome --new-window"
  ${SCRIPT_NAME} --workspace 4 --no-switch --exec "thunderbird"
  ${SCRIPT_NAME} --workspace 5 --switch --exec "alacritty"
EOF_USAGE
}

init_logging() {
  mkdir -p "${LOG_DIR}"
  LOG_FILE="${LOG_DIR}/setup-log-$(date +%Y%m%d-%H%M%S).log"
  touch "${LOG_FILE}"
}

log_line() {
  local level="$1"
  local message="$2"
  local timestamp

  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '[%s] [%s] %s\n' "${timestamp}" "${level}" "${message}" >>"${LOG_FILE}"

  if [[ "${level}" == "ERROR" || "${VERBOSE}" == "1" ]]; then
    printf '[%s] %s\n' "${level}" "${message}" >&2
  fi
}

die() {
  local message="$1"

  log_line "ERROR" "${message}"
  echo >&2
  usage >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

get_current_workspace_num() {
  local current_idx

  current_idx="$(wmctrl -d | awk '/\*/ { print $1 }')"
  [[ -n "${current_idx}" ]] || return 1

  echo $((current_idx + 1))
}

get_total_workspaces() {
  wmctrl -d | wc -l | tr -d ' '
}

switch_to_workspace() {
  local workspace_idx="$1"

  wmctrl -s "${workspace_idx}"
}

wait_for_window_id_by_pid() {
  local pid="$1"
  local attempts="40"
  local sleep_seconds="0.25"
  local window_id=""

  for ((i = 0; i < attempts; i += 1)); do
    window_id="$(wmctrl -lp | awk -v target_pid="${pid}" '$3 == target_pid { print $1; exit }')"

    if [[ -n "${window_id}" ]]; then
      echo "${window_id}"
      return 0
    fi

    sleep "${sleep_seconds}"
  done

  return 1
}

main() {
  init_logging

  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --help)
      usage
      exit 0
      ;;
    --verbose)
      VERBOSE="1"
      shift
      ;;
    --workspace)
      shift
      [[ $# -gt 0 ]] || die "--workspace requires a value"
      WORKSPACE_NUM="$1"
      shift
      ;;
    --tile)
      shift
      [[ $# -gt 0 ]] || die "--tile requires a value"
      TILE_TEMPLATE="$1"
      shift
      ;;
    --exec)
      shift
      [[ $# -gt 0 ]] || die "--exec requires a value"
      EXEC_COMMAND="$1"
      shift
      ;;
    --switch)
      SWITCH_WORKSPACE="1"
      shift
      ;;
    --no-switch)
      SWITCH_WORKSPACE="0"
      shift
      ;;
    *)
      die "Unknown option: $1"
      ;;
    esac
  done

  [[ -n "${EXEC_COMMAND}" ]] || die "--exec is required"

  need_cmd wmctrl || die "wmctrl is required. Install with: sudo apt install wmctrl"

  local current_workspace
  current_workspace="$(get_current_workspace_num)" || die "Could not determine current workspace"

  if [[ -z "${WORKSPACE_NUM}" ]]; then
    WORKSPACE_NUM="${current_workspace}"
  fi

  [[ "${WORKSPACE_NUM}" =~ ^[0-9]+$ ]] || die "--workspace must be a positive integer, got: ${WORKSPACE_NUM}"
  [[ "${WORKSPACE_NUM}" -ge 1 ]] || die "--workspace must be >= 1, got: ${WORKSPACE_NUM}"

  local total_workspaces
  total_workspaces="$(get_total_workspaces)"
  [[ "${WORKSPACE_NUM}" -le "${total_workspaces}" ]] || die "--workspace ${WORKSPACE_NUM} exceeds available workspaces (${total_workspaces})"

  local target_workspace_idx
  target_workspace_idx=$((WORKSPACE_NUM - 1))

  log_line "INFO" "Command: ${EXEC_COMMAND}"
  log_line "INFO" "Workspace: ${WORKSPACE_NUM}"
  log_line "INFO" "Switch before launch: ${SWITCH_WORKSPACE}"

  if [[ -n "${TILE_TEMPLATE}" ]]; then
    log_line "INFO" "Tile template: ${TILE_TEMPLATE}"
  fi

  if [[ "${WORKSPACE_NUM}" != "${current_workspace}" ]]; then
    if [[ "${SWITCH_WORKSPACE}" == "1" ]]; then
      log_line "INFO" "Switching to workspace ${WORKSPACE_NUM}"
      switch_to_workspace "${target_workspace_idx}"
    else
      log_line "INFO" "Staying on current workspace ${current_workspace} and launching for workspace ${WORKSPACE_NUM}"
    fi
  else
    log_line "INFO" "Using current workspace ${WORKSPACE_NUM}"
  fi

  bash -lc "${EXEC_COMMAND}" &
  local launch_pid="$!"
  disown "${launch_pid}" || true
  log_line "INFO" "Launched command with PID ${launch_pid}"

  if [[ "${WORKSPACE_NUM}" != "${current_workspace}" && "${SWITCH_WORKSPACE}" == "0" ]] || [[ -n "${TILE_TEMPLATE}" ]]; then
    local window_id

    if window_id="$(wait_for_window_id_by_pid "${launch_pid}")"; then
      log_line "INFO" "Detected window id ${window_id} for PID ${launch_pid}"

      if [[ "${WORKSPACE_NUM}" != "${current_workspace}" ]]; then
        wmctrl -i -r "${window_id}" -t "${target_workspace_idx}"
        log_line "INFO" "Moved window ${window_id} to workspace ${WORKSPACE_NUM}"
      fi

      if [[ -n "${TILE_TEMPLATE}" ]]; then
        local tile_cmd=("${SCRIPT_DIR}/wm-tile-window.sh" "--template" "${TILE_TEMPLATE}" "--window-id" "${window_id}")

        if [[ "${VERBOSE}" == "1" ]]; then
          tile_cmd+=("--verbose")
        fi

        "${tile_cmd[@]}"
        log_line "INFO" "Applied tile template '${TILE_TEMPLATE}' to window ${window_id}"
      fi
    else
      die "Unable to find a window for PID ${launch_pid}. Command may have forked immediately or did not open a window."
    fi
  fi

  log_line "INFO" "Completed successfully"
}

main "$@"
