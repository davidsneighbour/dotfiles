#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(CDPATH="" cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASHRC_DIR="$(CDPATH="" cd -- "${SCRIPT_DIR}/../.." && pwd)"
WORKSPACE_LAUNCHER="${BASHRC_DIR}/workspaces/ws_launch_program"

MEMORY_WORKSPACE="5"
MEMORY_REPO_PATH="${HOME}/github.com/davidsneighbour/memory"
MEMORY_VAULT_PATH="${MEMORY_REPO_PATH}/vault"
VERBOSE="0"

usage() {
  cat <<EOF_USAGE
${SCRIPT_NAME} [--verbose] [--help]

Open the Obsidian memory vault and its repository on the notes workspace.

Options:
  --verbose
      Print commands before launching them.

  --help
      Show this help.

Behaviour:
  * switches to workspace ${MEMORY_WORKSPACE}
  * opens the Obsidian vault at ${MEMORY_VAULT_PATH}
  * opens VS Code for ${MEMORY_REPO_PATH}
EOF_USAGE
}

die() {
  local message="$1"

  printf 'ERROR: %s\n\n' "${message}" >&2
  usage >&2
  exit 1
}

logv() {
  local message="$1"

  if [[ "${VERBOSE}" == "1" ]]; then
    printf 'DEBUG: %s\n' "${message}" >&2
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

quote_shell_word() {
  local value="$1"

  printf '%q' "${value}"
}

url_encode() {
  local value="$1"
  local encoded=""
  local char=""
  local i

  LC_ALL=C

  for ((i = 0; i < ${#value}; i += 1)); do
    char="${value:i:1}"

    case "${char}" in
    [a-zA-Z0-9.~_-])
      encoded+="${char}"
      ;;
    *)
      printf -v encoded '%s%%%02X' "${encoded}" "'${char}"
      ;;
    esac
  done

  printf '%s' "${encoded}"
}

launch_on_memory_workspace() {
  local command="$1"
  local -a launcher_args=(
    "--workspace" "${MEMORY_WORKSPACE}"
    "--switch"
    "--exec" "${command}"
  )

  if [[ "${VERBOSE}" == "1" ]]; then
    launcher_args+=("--verbose")
  else
    launcher_args+=("--quiet")
  fi

  logv "Launching on workspace ${MEMORY_WORKSPACE}: ${command}"
  "${WORKSPACE_LAUNCHER}" "${launcher_args[@]}"
}

main() {
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
    *)
      die "Unknown option: $1"
      ;;
    esac
  done

  [[ -x "${WORKSPACE_LAUNCHER}" ]] || die "Workspace launcher is not executable: ${WORKSPACE_LAUNCHER}"
  [[ -d "${MEMORY_REPO_PATH}" ]] || die "Memory repository not found: ${MEMORY_REPO_PATH}"
  [[ -d "${MEMORY_VAULT_PATH}" ]] || die "Memory vault folder not found: ${MEMORY_VAULT_PATH}"

  need_cmd wmctrl || die "wmctrl is required. Install with: sudo apt install wmctrl"
  need_cmd obsidian || die "obsidian is required but was not found in PATH"
  need_cmd code || die "code is required but was not found in PATH"

  local obsidian_command
  local obsidian_uri
  local code_command

  obsidian_uri="obsidian://open?path=$(url_encode "${MEMORY_VAULT_PATH}")"
  obsidian_command="obsidian $(quote_shell_word "${obsidian_uri}")"
  code_command="code --new-window $(quote_shell_word "${MEMORY_REPO_PATH}")"

  launch_on_memory_workspace "${obsidian_command}"
  launch_on_memory_workspace "${code_command}"
}

main "$@"
