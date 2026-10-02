#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
entry_path="${SCRIPT_DIR}/src/sync-cli.ts"
node_command="${GIT_COMMIT_REPORTS_NODE:-node}"
if [[ "${1:-}" == '--archive' ]]; then
  entry_path="${SCRIPT_DIR}/src/archive-cli.ts"
  shift
elif [[ "${1:-}" == '--scheduled' ]]; then
  entry_path="${SCRIPT_DIR}/src/schedule-cli.ts"
  shift
fi
quiet_mode='false'
inspect_mode='false'
has_vault='false'
has_action='false'

for argument in "${@}"; do
  case "${argument}" in
  --quiet) quiet_mode='true' ;;
  --verbose) export DNB_VERBOSE='1' ;;
  --help | --dry-run | inventory | --action=inventory) inspect_mode='true' ;;
  --vault | --vault=*) has_vault='true' ;;
  --action | --action=*) has_action='true' ;;
  *) : ;; # The TypeScript CLI validates other flags and values.
  esac
done
if [[ "${quiet_mode}" == 'true' ]]; then
  unset DNB_VERBOSE
fi
if [[ "${inspect_mode}" == 'true' || "${has_vault}" == 'false' || ( "${entry_path}" == */archive-cli.ts && "${has_action}" == 'false' ) ]]; then
  exec "${node_command}" --experimental-strip-types "${entry_path}" "${@}"
fi

# shellcheck source=bashrc/lib/00-core/dnb-core-colors.bash
source "${REPO_ROOT}/bashrc/lib/00-core/dnb-core-colors.bash"
# shellcheck source=bashrc/lib/00-core/dnb-core-log.bash
source "${REPO_ROOT}/bashrc/lib/00-core/dnb-core-log.bash"
log_directory="${HOME}/.logs/daily-reports"
if ! mkdir -p -- "${log_directory}"; then
  printf '%s\n' 'Cannot create daily-reports log directory; check home directory permissions.' >&2
  exit 1
fi
DNB_SETUP_LOG_FILE="${log_directory}/$(date +%Y%m%d-%H%M%S).log"
export DNB_SETUP_LOG_FILE
export __LOGFILE="${DNB_SETUP_LOG_FILE}"
export LOG_LEVEL='info'
dnb_log_init >/dev/null
export GIT_COMMIT_REPORTS_LOGGING='1'

if "${node_command}" --experimental-strip-types "${entry_path}" "${@}" 2>&1 | while IFS= read -r line; do
  if [[ "${line}" == ERROR\ * ]]; then
    dnb_log error "${line}" >&2
  elif [[ "${quiet_mode}" == 'true' || ( "${DNB_VERBOSE:-}" != '1' && "${line}" != Sync\ * && "${line}" != Archive\ * ) ]]; then
    dnb_log info "${line}" >/dev/null
  else
    dnb_log info "${line}"
  fi
done; then
  exit 0
else
  exit 1
fi
