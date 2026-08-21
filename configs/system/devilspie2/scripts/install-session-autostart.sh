#!/bin/bash

set -Eeuo pipefail

show_help() {
  cat <<'EOF'
Usage:
  install-session-autostart.sh [--dry-run] [--verbose] [--quiet]
  install-session-autostart.sh --help

Description:
  Install the Devilspie2 systemd user units for the current desktop session,
  reload the user manager, and enable Devilspie2 plus its config watcher.

Options:
  --dry-run   Print the actions without copying files or running systemctl.
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

run() {
  if [[ "${dry_run}" == 'true' ]]; then
    printf 'dry-run:'
    printf ' %q' "${@}"
    printf '\n'
    return 0
  fi

  info "Running: ${*}"
  "${@}"
}

require_command() {
  local command_name="${1}"

  command -v "${command_name}" >/dev/null 2>&1 \
    || die "Required command not found: ${command_name}"
}

main() {
  dry_run='false'
  local quiet_mode='false'
  verbose_mode='false'

  if [[ "${DNB_VERBOSE:-}" == '1' ]]; then
    verbose_mode='true'
  fi

  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
    --dry-run)
      dry_run='true'
      shift
      ;;
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

  require_command install
  require_command systemctl

  if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    die 'XDG_RUNTIME_DIR is not set. Run this inside the logged-in desktop session.'
  fi

  local script_dir
  local repo_dir
  local source_dir
  local target_dir

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  repo_dir="$(cd -- "${script_dir}/.." && pwd)"
  source_dir="${repo_dir}/systemd/user"
  target_dir="${HOME}/.config/systemd/user"

  [[ -d "${source_dir}" ]] \
    || die "Systemd unit source directory not found: ${source_dir}"

  run install -d "${target_dir}"
  run install -m 0644 "${source_dir}/devilspie2.service" "${target_dir}/devilspie2.service"
  run install -m 0644 "${source_dir}/devilspie2.path" "${target_dir}/devilspie2.path"
  run install -m 0644 "${source_dir}/devilspie2-restart.service" "${target_dir}/devilspie2-restart.service"

  run systemctl --user daemon-reload
  run systemctl --user enable --now devilspie2.service
  run systemctl --user enable --now devilspie2.path

  if [[ "${dry_run}" != 'true' ]]; then
    printf 'Devilspie2 user service installed and enabled.\n'
  fi
}

main "${@}"
