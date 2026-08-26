#!/bin/bash

set -Eeuo pipefail

show_help() {
  cat <<'EOF'
Usage:
  restart-devilspie2.sh [--verbose] [--quiet]
  restart-devilspie2.sh --help

Description:
  Reload Devilspie2 rules by killing any running instance and starting a new
  one detached from the terminal. Devilspie2 loads its Lua rule files once at
  startup, so this is the manual equivalent of the old systemd config-watch
  restart, for use after editing files in ~/.config/devilspie2 (the symlinked
  config/ directory in this repository).

Options:
  --verbose   Print progress messages.
  --quiet     Suppress progress messages.
  --help      Show this help.
EOF
}

die() {
  printf 'Error: %s\n' "${*}" >&2
  exit 1
}

info() {
  if [[ "${verbose_mode}" == 'true' ]]; then
    printf '%s\n' "${*}" >&2
  fi
}

require_command() {
  local command_name="${1}"

  command -v "${command_name}" >/dev/null 2>&1 \
    || die "Required command not found: ${command_name}"
}

main() {
  local quiet_mode='false'
  verbose_mode='false'

  if [[ "${DNB_VERBOSE:-}" == '1' ]]; then
    verbose_mode='true'
  fi

  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
    --verbose)
      verbose_mode='true'
      export DNB_VERBOSE='1'
      shift
      ;;
    --quiet)
      quiet_mode='true'
      shift
      ;;
    --help)
      show_help
      return 0
      ;;
    *)
      show_help >&2
      die "Unknown argument: ${1}"
      ;;
    esac
  done

  if [[ "${quiet_mode}" == 'true' ]]; then
    verbose_mode='false'
    unset DNB_VERBOSE
  fi

  require_command devilspie2
  require_command pkill

  if pgrep -x devilspie2 >/dev/null 2>&1; then
    info 'Stopping running devilspie2 instance.'
    pkill -x devilspie2 || true
    for _ in $(seq 1 20); do
      pgrep -x devilspie2 >/dev/null 2>&1 || break
      sleep 0.1
    done
  fi

  info 'Starting devilspie2.'
  nohup devilspie2 >/dev/null 2>&1 &
  disown

  info 'Devilspie2 restarted.'
}

main "${@}"
