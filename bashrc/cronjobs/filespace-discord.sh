#!/bin/bash
#
# Checks root filesystem usage and posts a Discord warning when usage
# exceeds a threshold.
#
# Cron example:
# 30 */4 * * * /path/to/filespace-discord.sh >> "$HOME/.logs/cron/job-$(date +\%Y\%m\%d-\%H\%M\%S).log" 2>&1

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

DEFAULT_PROJECT_NAME="Behemoth"
DEFAULT_THRESHOLD="80"

PROJECT_NAME="${DEFAULT_PROJECT_NAME}"
THRESHOLD="${DEFAULT_THRESHOLD}"

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Checks root ("/") filesystem usage and posts a Discord warning when usage
exceeds a threshold.

Options:
  --project-name NAME    Label used in the Discord alert.
                          Default: ${DEFAULT_PROJECT_NAME}

  --threshold PERCENT     Disk usage percent that triggers an alert.
                          Default: ${DEFAULT_THRESHOLD}

  --help                  Show this help.

Requires DISCORD_WEBHOOK (sourced from ~/.env if present). Missing or empty
DISCORD_WEBHOOK is not an error: the check still runs, the alert is skipped.
EOF
}

log_warn() {
  echo "[warn] $*" >&2
}

parse_args() {
  while (($# > 0)); do
    case "${1}" in
    --project-name)
      PROJECT_NAME="${2:-}"
      shift 2
      ;;
    --threshold)
      THRESHOLD="${2:-}"
      shift 2
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      log_warn "Unknown option: ${1}"
      print_help
      exit 1
      ;;
    esac
  done
}

load_env() {
  local env_file="${HOME}/.env"
  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${env_file}"
    set +a
  fi
}

main() {
  parse_args "$@"
  load_env

  local usage_percent
  usage_percent="$(df / | grep / | awk '{ print $5}' | sed 's/%//g')"

  if ((usage_percent <= THRESHOLD)); then
    return 0
  fi

  if [[ -z "${DISCORD_WEBHOOK:-}" ]]; then
    log_warn "DISCORD_WEBHOOK is not set; skipping disk-space alert (usage: ${usage_percent}%)."
    return 0
  fi

  # shellcheck disable=SC2154
  curl --location --request POST "${DISCORD_WEBHOOK}" \
    --form "content=:floppy_disk: The disk space for ${PROJECT_NAME} is critical. Used: ${usage_percent}%. Please clean up some space." \
    --form "username=Disk Space Alert"
}

main "$@"
