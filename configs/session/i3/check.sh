#!/bin/bash
#
# Read-only diagnostic check for the i3 starter session: reports whether
# i3, Polybar, and Rofi are installed and (where applicable) running.
# Never modifies the desktop — see SESSION.md "Diagnostic commands".

set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
I3_CONFIG="${REPO_DIR}/configs/session/i3/config"
ROFI_CONFIG="${REPO_DIR}/configs/session/i3/rofi.rasi"
POLYBAR_CONFIG="${REPO_DIR}/configs/session/polybar/config.ini"
POLYBAR_LOG_DIR="${HOME}/.logs/polybar-i3"

print_help() {
  cat <<EOF
Usage: $(basename "${0}") [--help]

Read-only report on whether the i3 starter session's components (i3,
Polybar, Rofi) are installed and running. Makes no changes to the desktop.

Checks:
  - i3, polybar, rofi executables on PATH, with version if found
  - configs/session/i3/config validates via \`i3 -C\`
  - whether an i3 process is currently running, and its IPC socket
  - whether the i3-session Polybar bar is currently running
  - most recent i3-session Polybar log file, if any
  - current XDG_CURRENT_DESKTOP / DESKTOP_SESSION

Options:
  --help   Show this help and exit.
EOF
}

if [[ "${1:-}" == "--help" ]]; then
  print_help
  exit 0
fi

if [[ "${#}" -gt 0 ]]; then
  printf 'Unknown argument: %s\n\n' "${1}" >&2
  print_help >&2
  exit 2
fi

ok() { printf '  [ok]   %s\n' "${1}"; }
warn() { printf '  [warn] %s\n' "${1}"; }
info() { printf '  [info] %s\n' "${1}"; }

check_executable() {
  local name="${1}"
  local version_flag="${2}"

  if command -v "${name}" >/dev/null 2>&1; then
    ok "${name}: $(command -v "${name}") ($("${name}" "${version_flag}" 2>&1 | head -n1))"
  else
    warn "${name}: not found on PATH"
  fi
}

printf 'Executables\n'
check_executable i3 --version
check_executable polybar --version
check_executable rofi -version

printf '\nConfig files\n'
if [[ -f "${I3_CONFIG}" ]]; then
  if i3 -C -c "${I3_CONFIG}" >/dev/null 2>&1; then
    ok "i3 config valid: ${I3_CONFIG}"
  else
    warn "i3 config FAILED validation: ${I3_CONFIG} (run: i3 -C -c ${I3_CONFIG})"
  fi
else
  warn "i3 config not found: ${I3_CONFIG}"
fi

if [[ -f "${ROFI_CONFIG}" ]]; then
  ok "rofi override present: ${ROFI_CONFIG}"
else
  warn "rofi override missing: ${ROFI_CONFIG}"
fi

if [[ -f "${POLYBAR_CONFIG}" ]]; then
  ok "polybar config present: ${POLYBAR_CONFIG}"
else
  warn "polybar config missing: ${POLYBAR_CONFIG}"
fi

printf '\nRunning processes\n'
if pgrep -x i3 >/dev/null 2>&1; then
  ok "i3 is running (pid: $(pgrep -x i3 | tr '\n' ' '))"

  I3_SOCKET_FOUND=0
  for socket in "/run/user/${UID}/i3/ipc-socket."*; do
    [[ -S "${socket}" ]] && I3_SOCKET_FOUND=1
    break
  done

  if [[ "${I3_SOCKET_FOUND}" -eq 1 ]]; then
    ok "i3 IPC socket present"
  else
    info "i3 IPC socket not found at the expected default location (i3 may use a non-default one)"
  fi
else
  info "i3 is not currently running"
fi

if pgrep -u "${UID}" -x polybar >/dev/null 2>&1; then
  ok "polybar is running (pid: $(pgrep -u "${UID}" -x polybar | tr '\n' ' '))"
  pgrep -u "${UID}" -a -x polybar | while IFS= read -r line; do
    info "  ${line}"
  done
else
  info "polybar is not currently running"
fi

printf '\nLogs\n'
if [[ -d "${POLYBAR_LOG_DIR}" ]]; then
  LATEST_LOG="$(find "${POLYBAR_LOG_DIR}" -maxdepth 1 -name 'bar-*.log' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)"
  if [[ -n "${LATEST_LOG}" ]]; then
    ok "latest i3 Polybar log: ${LATEST_LOG}"
    if grep -qi 'error' "${LATEST_LOG}"; then
      warn "  contains lines matching 'error' — check with: tail -50 ${LATEST_LOG}"
    fi
  else
    info "no i3 Polybar log files found yet in ${POLYBAR_LOG_DIR}"
  fi
else
  info "i3 Polybar log directory does not exist yet: ${POLYBAR_LOG_DIR}"
fi

printf '\nSession\n'
info "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-<unset>}"
info "DESKTOP_SESSION=${DESKTOP_SESSION:-<unset>}"
