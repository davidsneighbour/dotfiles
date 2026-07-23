#!/bin/bash

set -Eeuo pipefail

show_help() {
  cat <<'EOF'
Run the mailbox quota monitor.

Options:
  --env-file FILE       Environment file to source. Default: ~/.env
  --script FILE         Monitor script path. Default: ./monitor-mailboxes.mjs
  --working-dir DIR     Working directory. Default: script directory
  --help                Show this help.

Example:
  ./run-mailbox-monitor.sh --env-file ~/.env
EOF
}

load_env() {
  local env_file=""

  while (($#)); do
    case "$1" in
      --env-file)
        env_file="${2:-}"
        shift 2
        ;;
      --help)
        cat <<'EOF'
load_env

Options:
  --env-file FILE       Environment file to source.
  --help                Show this help.
EOF
        return 0
        ;;
      *)
        echo "Unknown load_env option: $1" >&2
        return 2
        ;;
    esac
  done

  if [[ -z "${env_file}" ]]; then
    echo "load_env requires --env-file" >&2
    return 2
  fi

  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${env_file}"
    set +a
  fi
}

run_monitor() {
  local script=""
  local working_dir=""

  while (($#)); do
    case "$1" in
      --script)
        script="${2:-}"
        shift 2
        ;;
      --working-dir)
        working_dir="${2:-}"
        shift 2
        ;;
      --help)
        cat <<'EOF'
run_monitor

Options:
  --script FILE         Monitor script path.
  --working-dir DIR     Working directory.
  --help                Show this help.
EOF
        return 0
        ;;
      *)
        echo "Unknown run_monitor option: $1" >&2
        return 2
        ;;
    esac
  done

  if [[ -z "${script}" ]]; then
    echo "run_monitor requires --script" >&2
    return 2
  fi

  if [[ -z "${working_dir}" ]]; then
    echo "run_monitor requires --working-dir" >&2
    return 2
  fi

  cd "${working_dir}"
  "${MAILBOX_MONITOR_NODE_BIN:-node}" "${script}"
}

main() {
  local env_file="${HOME}/.env"
  local script_dir=""
  local script_file="monitor-mailboxes.mjs"
  local working_dir=""

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  working_dir="${script_dir}"

  while (($#)); do
    case "$1" in
      --env-file)
        env_file="${2:-}"
        shift 2
        ;;
      --script)
        script_file="${2:-}"
        shift 2
        ;;
      --working-dir)
        working_dir="${2:-}"
        shift 2
        ;;
      --help)
        show_help
        return 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        show_help >&2
        return 2
        ;;
    esac
  done

  load_env --env-file "${env_file}"
  run_monitor --script "${script_file}" --working-dir "${working_dir}"
}

main "$@"
