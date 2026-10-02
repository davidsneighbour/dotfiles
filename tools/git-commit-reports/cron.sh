#!/bin/bash
set -euo pipefail
script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
node_path=''
arguments=()
while (( $# > 0 )); do
  case "${1}" in
  --node)
    if (( $# < 2 )); then
      printf '%s\n' 'ERROR --node requires an absolute executable path.' >&2
      exit 1
    fi
    node_path="${2}"
    shift 2
    ;;
  --node=*) node_path="${1#*=}"; shift ;;
  *) arguments+=("${1}"); shift ;;
  esac
done
if [[ "${#arguments[@]}" == '1' && "${arguments[0]}" == '--help' && -z "${node_path}" ]]; then
  printf '%s\n' 'Usage: cron.sh --node ABSOLUTE_PATH --vault PATH [--if-due] [--dry-run] [--verbose | --quiet]'
  printf '%s\n' 'Daily sync with catch-up at 08:00 Asia/Bangkok. --node is an explicit Node.js executable; --vault is required.'
  exit 0
fi
if [[ "${node_path}" != /* || ! -x "${node_path}" ]]; then
  printf '%s\n' 'Usage: cron.sh --node ABSOLUTE_PATH --vault PATH [--if-due] [--dry-run] [--verbose | --quiet]' >&2
  printf '%s\n' 'ERROR Set --node to an installed Node.js executable; no shell startup files are loaded.' >&2
  exit 1
fi
node_directory="$(dirname -- "${node_path}")"
export PATH="${node_directory}:/usr/bin:/bin"
export GIT_COMMIT_REPORTS_NODE="${node_path}"
exec /bin/bash "${script_directory}/sync.sh" --scheduled "${arguments[@]}"
