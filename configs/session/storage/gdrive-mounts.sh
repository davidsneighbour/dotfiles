#!/bin/bash
#
# Mount Google Drive accounts with google-drive-ocamlfuse and report failures.
#
# Started without arguments from i3 (configs/session/i3/configs/session-starts.conf).
# google-drive-ocamlfuse runs in the background and writes its errors only to
# its own output, so a failed mount was silent. This script now waits for each
# mount, and shows a desktop notification when a mount fails. When Google
# rejects the stored refresh token, the notification offers a "Re-authorise"
# action (middle-click the notification in dunst) that runs `--reauth`.
#
# Re-authorisation: google-drive-ocamlfuse starts the OAuth flow only when the
# stored refresh token is empty, and exits after setup when it gets no
# mountpoint. `--reauth` therefore moves the state file aside, runs
# `google-drive-ocamlfuse -label <label>` without a mountpoint (this opens the
# browser), and then mounts the drive again.

set -u -o pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_NAME="$(basename "${SCRIPT_PATH}")"
LABELS=("pkollitsch" "davidsneighbour")
MOUNT_BASE="${HOME}/GoogleDrive"
LOG_BASE="${HOME}/.logs/gdrive"
MOUNT_TIMEOUT=20
VERBOSE="${DNB_VERBOSE:-0}"
LOGFILE=""

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--reauth] [--label <label>] [--no-notify] [--verbose] [--quiet] [--help]

Mount Google Drive accounts with google-drive-ocamlfuse at ${MOUNT_BASE}/<label>.
Without options, all configured labels are mounted (${LABELS[*]}).

Options:
  --label <label>  Work on this label only (default: all configured labels).
  --reauth         Discard the stored refresh token of the label(s), start the
                   browser-based Google authorisation, then mount again.
  --no-notify      Do not show desktop notifications.
  --verbose        Print progress to the terminal.
  --quiet          Print errors only (overrides --verbose and DNB_VERBOSE).
  --help           Show this help and exit.

Logs:
  ${LOG_BASE}/<label>/YYYYMMDD-HHMMSS.log

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --reauth --label pkollitsch
EOF
}

log() {
  local level="${1}"
  local message="${2}"
  if [[ -n "${LOGFILE}" ]]; then
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${level}" "${message}" >>"${LOGFILE}"
  fi
  if [[ "${level}" == "error" ]]; then
    printf '%s: %s\n' "${SCRIPT_NAME}" "${message}" >&2
  elif [[ "${VERBOSE}" == "1" ]]; then
    printf '%s\n' "${message}"
  fi
}

init_log() {
  local label="${1}"
  mkdir -p "${LOG_BASE}/${label}"
  LOGFILE="${LOG_BASE}/${label}/$(date +%Y%m%d-%H%M%S).log"
}

# Directory that holds the `state` file (with the refresh token) of a label.
# Mirrors AppDir.create in google-drive-ocamlfuse: the XDG layout is used when
# an XDG config file exists for the label, else the legacy ~/.gdfuse layout.
state_dir() {
  local label="${1}"
  if [[ -f "${XDG_CONFIG_HOME:-${HOME}/.config}/gdfuse/${label}/config" ]]; then
    printf '%s\n' "${XDG_DATA_HOME:-${HOME}/.local/share}/gdfuse/${label}"
  else
    printf '%s\n' "${HOME}/.gdfuse/${label}"
  fi
}

# Show a notification. With an action, wait in the background for the click
# and run the matching command, so the caller (i3) is never blocked.
notify() {
  local urgency="${1}"
  local summary="${2}"
  local body="${3}"
  local action_label="${4:-}"
  shift "$((${#} < 4 ? ${#} : 4))"

  if [[ "${NOTIFY}" != "1" ]]; then
    return 0
  fi
  if ! command -v notify-send >/dev/null 2>&1; then
    log "warn" "notify-send not found; notification not shown: ${summary}"
    return 0
  fi

  if [[ -z "${action_label}" ]]; then
    notify-send --app-name="gdrive-mounts" --urgency="${urgency}" "${summary}" "${body}" ||
      log "warn" "notify-send failed for: ${summary}"
    return 0
  fi

  (
    local choice
    choice="$(notify-send --app-name="gdrive-mounts" --urgency="${urgency}" \
      --action="run=${action_label}" --wait "${summary}" "${body}")" ||
      log "warn" "notify-send failed for: ${summary}"
    if [[ "${choice}" == "run" ]]; then
      "${@}"
    fi
  ) &
  disown
}

# Remove a stale FUSE mount left by a crashed google-drive-ocamlfuse process
# ("Transport endpoint is not connected"), which would block a new mount.
clear_stale_mount() {
  local mountpoint="${1}"
  if grep -qs " ${mountpoint} fuse" /proc/mounts && ! mountpoint -q "${mountpoint}" 2>/dev/null; then
    log "warn" "Removing stale FUSE mount at ${mountpoint}"
    fusermount -u -z "${mountpoint}" >>"${LOGFILE}" 2>&1 ||
      log "error" "Could not remove stale mount at ${mountpoint}"
  fi
}

mount_google_drive() {
  local label="${1}"
  local mountpoint="${MOUNT_BASE}/${label}"
  local pid
  local waited=0

  init_log "${label}"
  clear_stale_mount "${mountpoint}"

  if mountpoint -q "${mountpoint}" 2>/dev/null; then
    log "info" "${label}: already mounted at ${mountpoint}"
    return 0
  fi

  if ! mkdir -p "${mountpoint}"; then
    log "error" "${label}: cannot create mountpoint ${mountpoint}"
    notify "critical" "Google Drive: ${label} not mounted" "Cannot create ${mountpoint}."
    return 1
  fi

  log "info" "${label}: mounting at ${mountpoint}"
  google-drive-ocamlfuse -label "${label}" "${mountpoint}" >>"${LOGFILE}" 2>&1 &
  pid="${!}"

  # google-drive-ocamlfuse stays in the foreground until it is mounted and
  # then daemonises, or it exits on an error. Wait for either result.
  while ((waited < MOUNT_TIMEOUT)); do
    if mountpoint -q "${mountpoint}" 2>/dev/null; then
      log "info" "${label}: mounted"
      return 0
    fi
    if ! kill -0 "${pid}" 2>/dev/null; then
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done

  # The foreground process exits once it has daemonised; give the mount a
  # moment to become visible before calling it a failure.
  for _ in 1 2 3; do
    if mountpoint -q "${mountpoint}" 2>/dev/null; then
      log "info" "${label}: mounted"
      return 0
    fi
    sleep 1
  done

  if grep -qs "Invalid refresh token" "${LOGFILE}"; then
    log "error" "${label}: Google rejected the refresh token. Run: ${SCRIPT_NAME} --reauth --label ${label}"
    notify "critical" "Google Drive: ${label} needs sign-in" \
      "The refresh token is no longer valid. Middle-click to re-authorise in the browser, or run: ${SCRIPT_NAME} --reauth --label ${label}" \
      "Re-authorise" "${SCRIPT_PATH}" --reauth --label "${label}"
  else
    log "error" "${label}: mount failed, see ${LOGFILE}"
    notify "critical" "Google Drive: ${label} not mounted" "Mount failed. Log: ${LOGFILE}"
  fi
  return 1
}

reauth_google_drive() {
  local label="${1}"
  local mountpoint="${MOUNT_BASE}/${label}"
  local dir
  local state
  local backup

  init_log "${label}"
  dir="$(state_dir "${label}")"
  state="${dir}/state"

  if mountpoint -q "${mountpoint}" 2>/dev/null; then
    log "error" "${label}: mounted at ${mountpoint}, so the token works. Unmount it first (fusermount -u ${mountpoint}) to force re-authorisation."
    return 1
  fi

  if pgrep -u "${UID}" -f -- "google-drive-ocamlfuse -label ${label}( |$)" >/dev/null 2>&1; then
    log "error" "${label}: a google-drive-ocamlfuse process for this label is still running. Stop it first."
    return 1
  fi

  if [[ -f "${state}" ]]; then
    backup="${state}.bak-$(date +%Y%m%d-%H%M%S)"
    if ! mv -- "${state}" "${backup}"; then
      log "error" "${label}: cannot move ${state} aside"
      return 1
    fi
    chmod 600 "${backup}"
    log "info" "${label}: old state moved to ${backup}"
  fi

  log "info" "${label}: starting Google authorisation in the browser"
  notify "normal" "Google Drive: ${label}" "Complete the Google sign-in in the browser window."

  if ! google-drive-ocamlfuse -label "${label}" >>"${LOGFILE}" 2>&1 || [[ ! -f "${state}" ]] ||
    ! grep -qs '^refresh_token=.' "${state}"; then
    log "error" "${label}: authorisation failed, see ${LOGFILE}"
    if [[ -n "${backup:-}" && -f "${backup}" ]]; then
      mv -f -- "${backup}" "${state}" && log "info" "${label}: old state restored"
    fi
    notify "critical" "Google Drive: ${label} sign-in failed" "Log: ${LOGFILE}"
    return 1
  fi

  # The state file holds the refresh token; keep it private.
  chmod 600 "${state}"
  log "info" "${label}: authorisation complete"

  mount_google_drive "${label}" || return 1
  notify "normal" "Google Drive: ${label} mounted" "${mountpoint}"
}

REAUTH=0
NOTIFY=1
SELECTED_LABEL=""
QUIET=0

while [[ "${#}" -gt 0 ]]; do
  case "${1}" in
  --help)
    print_help
    exit 0
    ;;
  --reauth)
    REAUTH=1
    ;;
  --label)
    if [[ -z "${2:-}" ]]; then
      printf '%s: --label needs a value\n\n' "${SCRIPT_NAME}" >&2
      print_help >&2
      exit 2
    fi
    SELECTED_LABEL="${2}"
    shift
    ;;
  --no-notify)
    NOTIFY=0
    ;;
  --verbose)
    VERBOSE=1
    ;;
  --quiet)
    QUIET=1
    ;;
  *)
    printf '%s: unknown argument: %s\n\n' "${SCRIPT_NAME}" "${1}" >&2
    print_help >&2
    exit 2
    ;;
  esac
  shift
done

if [[ "${QUIET}" == "1" ]]; then
  VERBOSE=0
  unset DNB_VERBOSE
elif [[ "${VERBOSE}" == "1" ]]; then
  export DNB_VERBOSE=1
fi

if ! command -v google-drive-ocamlfuse >/dev/null 2>&1; then
  printf '%s: google-drive-ocamlfuse not found on PATH\n' "${SCRIPT_NAME}" >&2
  exit 1
fi

if [[ -n "${SELECTED_LABEL}" ]]; then
  LABELS=("${SELECTED_LABEL}")
fi

status=0
for label in "${LABELS[@]}"; do
  if [[ "${REAUTH}" == "1" ]]; then
    reauth_google_drive "${label}" || status=1
  else
    mount_google_drive "${label}" || status=1
  fi
done

exit "${status}"
