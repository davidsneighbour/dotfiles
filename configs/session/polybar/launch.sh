#!/bin/bash
#
# Launch the i3 starter Polybar bar.
#
# This script is intentionally separate from configs/system/polybar/start.sh
# (the XFCE bar's launcher): that one waits for xfwm4 and only makes sense
# under XFCE. This one is i3-only.
#
# Safe to run from i3's `exec_always`: it never exits non-zero in a way that
# would matter to i3 (i3 does not act on exec_always exit status), and it
# is safe to run repeatedly (e.g. on `i3-msg restart`) because it kills its
# own previous bar instance first.
#
# NOTE: this script matches Polybar processes by binary name only (`-x
# polybar`), not by config file. That is safe here because i3 and XFCE are
# alternate, mutually exclusive LightDM sessions on this workstation (see
# SESSION.md) — the two are never running at the same time on the same
# display. Do not reuse this pattern in a setup where multiple bars might
# legitimately run concurrently for the same user.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.ini"
LOG_DIR="${HOME}/.logs/polybar-i3"
LOGLEVEL="info"

# Polybar click handlers (e.g. the powermenu module) run as children of the
# Polybar process started below. i3's `exec_always` runs this script from a
# plain, non-interactive, non-login shell that never sourced bashrc/.profile,
# so BASHRC_PATH would otherwise be missing for those handlers even though it
# is set for interactive shells and for i3 keybindings that set it inline
# (see i3/config's $mod+Shift+e binding).
export BASHRC_PATH="${HOME}/.dotfiles/bashrc"

print_help() {
  cat <<EOF
Usage: $(basename "${0}") [--help]

Start the i3 starter Polybar bar (configs/session/polybar/config.ini).

Behaviour:
  1. Terminates any existing Polybar instances owned by the current user.
  2. Waits (up to 5s) for them to exit.
  3. Starts the bar defined in config.ini, logging to:
       ${LOG_DIR}/bar-YYYYMMDD.log
  4. Never exits in a way that should be treated as fatal by a caller such
     as i3's exec_always; failures are logged, not thrown.

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

mkdir -p "${LOG_DIR}"
LOGFILE="${LOG_DIR}/bar-$(date +%Y%m%d).log"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${1}" >>"${LOGFILE}"
}

if ! command -v polybar >/dev/null 2>&1; then
  log "ERROR: polybar executable not found on PATH; not starting the bar."
  exit 0
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  log "ERROR: config file not found: ${CONFIG_FILE}; not starting the bar."
  exit 0
fi

if pgrep -u "${UID}" -x polybar >/dev/null 2>&1; then
  log "stopping existing polybar instance(s) for UID ${UID}"
  pkill -u "${UID}" -x polybar || true

  for _ in {1..20}; do
    pgrep -u "${UID}" -x polybar >/dev/null 2>&1 || break
    sleep 0.25
  done

  if pgrep -u "${UID}" -x polybar >/dev/null 2>&1; then
    log "WARNING: a polybar process is still running after waiting; starting anyway."
  fi
fi

log "starting bar/i3bar from ${CONFIG_FILE}"
polybar -l "${LOGLEVEL}" -c "${CONFIG_FILE}" i3bar >>"${LOGFILE}" 2>&1 &
disown || true

log "launch script done (pid of bar: $!)"
