#!/bin/bash
# Scheduled entry point: explicit Node binary, repository logging, and low I/O priority.
set -euo pipefail
storage_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${storage_dir}/../.." && pwd)"
node_binary=''
arguments=()
verbose='false'
quiet='false'
while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    --help)
      printf '%s\n' 'Usage: run.sh --node /absolute/path/to/node --index|--serve [CLI flags]' \
        'Runs the storage CLI and logs to ~/.logs/storage/YYYYMMDD-HHMMSS.log.' \
        'Supports --verbose, --quiet, and all src/cli.ts flags. No action prints help.'
      exit 0
      ;;
    --node)
      if [[ "$#" -lt 2 ]]; then
        printf '%s\n' 'Missing --node value. Use --help.' >&2
        exit 1
      fi
      node_binary="${2}"
      shift
      ;;
    --verbose)
      verbose='true'
      arguments+=("${1}")
      ;;
    --quiet)
      quiet='true'
      arguments+=("${1}")
      ;;
    *) arguments+=("${1}") ;;
  esac
  shift
done
if [[ "${#arguments[@]}" -eq 0 ]]; then
  printf '%s\n' 'Choose --index or --serve and supply --node. Use --help.'
  exit 0
fi
if [[ "${node_binary}" == "${HOME}/.local/bin/node-cron" ]]; then
  /bin/bash "${repo_root}/scripts/node-cron.sh" --refresh
fi
if [[ "${node_binary}" != /* || ! -x "${node_binary}" ]]; then
  printf '%s\n' 'Supply an executable absolute Node path with --node. Use --help.' >&2
  exit 1
fi
if [[ "${quiet}" == 'true' ]]; then
  unset DNB_VERBOSE
elif [[ "${verbose}" == 'true' ]]; then
  export DNB_VERBOSE=1
fi
# shellcheck source=bashrc/lib/00-core/dnb-core-colors.bash
source "${repo_root}/bashrc/lib/00-core/dnb-core-colors.bash"
# shellcheck source=bashrc/lib/00-core/dnb-core-log.bash
source "${repo_root}/bashrc/lib/00-core/dnb-core-log.bash"
mkdir -p "${HOME}/.logs/storage"
DNB_SETUP_LOG_FILE="${HOME}/.logs/storage/$(date +%Y%m%d-%H%M%S).log"
export DNB_SETUP_LOG_FILE
dnb_log_init >/dev/null
if [[ "${DNB_VERBOSE:-}" == '1' ]]; then
  dnb_log info 'Starting storage catalogue command'
fi
if /usr/bin/ionice -c 3 /usr/bin/nice -n 10 "${node_binary}" "${storage_dir}/src/cli.ts" "${arguments[@]}" >>"${DNB_SETUP_LOG_FILE}" 2>&1; then
  if [[ "${DNB_VERBOSE:-}" == '1' ]]; then
    dnb_log info 'Storage command finished'
  fi
else
  storage_status="$?"
  printf 'Storage command failed (%s). See %s\n' "${storage_status}" "${DNB_SETUP_LOG_FILE}" >&2
  exit "${storage_status}"
fi
