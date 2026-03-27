#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<USAGE
Usage:
  ${SCRIPT_NAME} [--issues-file <path>] [--settings-file <path>] [--gmail-credentials <path>] [--unread-file <path>] [--show-unread] [--verbose]
  ${SCRIPT_NAME} --help

Options:
  --issues-file <path>        TOML issues file to read (default: ~/.config/polybar/issues.toml).
  --settings-file <path>      Polybar settings INI file used for colours (default: ~/.dotfiles/configs/system/polybar/configs/01-settings.ini).
  --gmail-credentials <path>  Gmail API credentials file path for optional unread lookup.
  --unread-file <path>        Optional plain-text file containing a numeric unread count.
  --show-unread               Attempt to append unread count when available.
  --verbose                   Print debug messages to stderr.
  --help                      Show this help.
USAGE
}

log_debug() {
  local message="$1"
  if [[ "${VERBOSE}" == "1" ]]; then
    printf 'DEBUG: %s\n' "${message}" >&2
  fi
}

get_colour() {
  local key="$1"
  local value=""

  value="$({ grep -E "^${key}[[:space:]]*=" "${SETTINGS_FILE}" || true; } | head -n1 | awk -F'=' '{gsub(/[[:space:]]/, "", $2); print $2}')"
  printf '%s' "${value}"
}

get_unread_count() {
  local unread_raw=""

  if [[ -n "${MSGVAULT_UNREAD_COUNT:-}" ]]; then
    unread_raw="${MSGVAULT_UNREAD_COUNT}"
    log_debug "Using unread count from MSGVAULT_UNREAD_COUNT"
  elif [[ -f "${UNREAD_FILE}" ]]; then
    unread_raw="$(head -n1 "${UNREAD_FILE}" | tr -d '[:space:]')"
    log_debug "Using unread count from unread file: ${UNREAD_FILE}"
  elif command -v gmailctl >/dev/null 2>&1 && [[ -f "${GMAIL_CREDENTIALS}" ]]; then
    unread_raw="$({ timeout 5s gmailctl unread-count --credentials "${GMAIL_CREDENTIALS}"; } 2>/dev/null || true)"
    unread_raw="$(printf '%s' "${unread_raw}" | head -n1 | tr -d '[:space:]')"
    log_debug "Attempted unread lookup via gmailctl"
  fi

  if [[ "${unread_raw}" =~ ^[0-9]+$ ]]; then
    printf '%s' "${unread_raw}"
    return 0
  fi

  printf ''
}

ISSUES_FILE="${HOME}/.config/polybar/issues.toml"
SETTINGS_FILE="${HOME}/.dotfiles/configs/system/polybar/configs/01-settings.ini"
GMAIL_CREDENTIALS="${HOME}/github.com/davidsneighbour/dotfiles/modules/gmailctl/credentials.json"
UNREAD_FILE="${MSGVAULT_UNREAD_FILE:-${HOME}/.cache/gmailctl/unread_count}"
SHOW_UNREAD="0"
VERBOSE="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --help)
    usage
    exit 0
    ;;
  --issues-file)
    shift
    [[ $# -gt 0 ]] || {
      echo "ERROR: --issues-file requires a value" >&2
      usage >&2
      exit 1
    }
    ISSUES_FILE="$1"
    shift
    ;;
  --settings-file)
    shift
    [[ $# -gt 0 ]] || {
      echo "ERROR: --settings-file requires a value" >&2
      usage >&2
      exit 1
    }
    SETTINGS_FILE="$1"
    shift
    ;;
  --gmail-credentials)
    shift
    [[ $# -gt 0 ]] || {
      echo "ERROR: --gmail-credentials requires a value" >&2
      usage >&2
      exit 1
    }
    GMAIL_CREDENTIALS="$1"
    shift
    ;;
  --unread-file)
    shift
    [[ $# -gt 0 ]] || {
      echo "ERROR: --unread-file requires a value" >&2
      usage >&2
      exit 1
    }
    UNREAD_FILE="$1"
    shift
    ;;
  --show-unread)
    SHOW_UNREAD="1"
    shift
    ;;
  --verbose)
    VERBOSE="1"
    shift
    ;;
  *)
    echo "ERROR: Unknown option: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
done

if [[ ! -f "${SETTINGS_FILE}" ]]; then
  echo "ERROR: settings file not found: ${SETTINGS_FILE}" >&2
  exit 1
fi

red="$(get_colour red)"
green="$(get_colour green)"

if [[ -z "${red}" || -z "${green}" ]]; then
  echo "ERROR: could not resolve red/green colours from ${SETTINGS_FILE}" >&2
  exit 1
fi

issue_state="OK"
if [[ -f "${ISSUES_FILE}" ]]; then
  issue_state="$({
    python3 - "${ISSUES_FILE}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])

try:
    import tomllib
except ModuleNotFoundError:
    print("OK", end="")
    raise SystemExit(0)

try:
    data = tomllib.loads(path.read_text(encoding="utf-8"))
except Exception:
    print("OK", end="")
    raise SystemExit(0)

issues = data.get("issue", [])
if not isinstance(issues, list):
    issues = []

for item in issues:
    if not isinstance(item, dict):
        continue

    id_value = str(item.get("id", ""))
    label_value = str(item.get("label", ""))
    description_value = str(item.get("description", ""))
    blob = f"{id_value} {label_value} {description_value}".lower()

    if "msgvault" in blob:
        print("ISSUE", end="")
        raise SystemExit(0)

print("OK", end="")
PY
  } 2>/dev/null)"
fi

colour="${green}"
if [[ "${issue_state}" == "ISSUE" ]]; then
  colour="${red}"
fi

mail_icon="✉"
output="%{F${colour}}${mail_icon}%{F-}"

if [[ "${SHOW_UNREAD}" == "1" ]]; then
  unread_count="$(get_unread_count)"
  if [[ -n "${unread_count}" ]]; then
    output="${output} ${unread_count}"
  fi
fi

printf '%s\n' "${output}"
