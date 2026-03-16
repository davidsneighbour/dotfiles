#!/bin/bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_FILE="${SCRIPT_DIR}/synch_downloads.json"

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Options:
  --config <path>   Path to JSON config file (default: ${DEFAULT_CONFIG_FILE})
  --dry-run         Pass --dry-run to rsync (no changes)
  --verbose         Enable verbose output (adds -v to rsync)
  --help            Show this help and exit

Notes:
  * Requires: jq, rsync, ssh (for remote endpoints)
  * Config format: JSON (see synch_downloads.json next to the script)

EOF
}

log() {
  # shellcheck disable=SC2155
  local now="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[${now}] ${1}"
}

fail() {
  echo "Error: ${1}" 1>&2
  echo 1>&2
  print_help 1>&2
  exit 1
}

expand_tilde() {
  # Expands a leading "~/" in a path.
  # Usage: expanded="$(expand_tilde "~/.logs")"
  local p="${1}"
  if [[ "${p}" == "~/"* ]]; then
    echo "${HOME}/${p#~/}"
    return 0
  fi
  echo "${p}"
}

require_cmd() {
  local cmd="${1}"
  command -v "${cmd}" >/dev/null 2>&1 || fail "Missing required command: ${cmd}"
}

read_json_str() {
  local file="${1}"
  local jq_expr="${2}"
  jq -r "${jq_expr}" "${file}"
}

read_json_bool() {
  local file="${1}"
  local jq_expr="${2}"
  local val
  val="$(jq -r "${jq_expr}" "${file}")"
  if [[ "${val}" != "true" && "${val}" != "false" ]]; then
    fail "Expected boolean at: ${jq_expr}"
  fi
  echo "${val}"
}

json_has_key() {
  local file="${1}"
  local jq_expr="${2}"
  jq -e "${jq_expr}" "${file}" >/dev/null 2>&1
}

rsync_job() {
  local name="${1}"
  local from="${2}"
  local to="${3}"
  local delete_flag="${4}" # "true" or "false"
  local dry_run_flag="${5}" # "true" or "false"
  local verbose_flag="${6}" # "true" or "false"
  local config_file="${7}"
  local job_index="${8}"

  local -a args=()
  local -a base_args=()
  local -a excludes=()

  # base args
  mapfile -t base_args < <(jq -r '.rsync.base_args[]? // empty' "${config_file}")
  if [[ "${#base_args[@]}" -eq 0 ]]; then
    base_args=(-rzt)
  fi

  args+=("${base_args[@]}")

  if [[ "${verbose_flag}" == "true" ]]; then
    args+=(-v)
  fi

  if [[ "${dry_run_flag}" == "true" ]]; then
    args+=(--dry-run)
  fi

  if [[ "${delete_flag}" == "true" ]]; then
    args+=(--delete)
  fi

  # global excludes
  mapfile -t excludes < <(jq -r '.exclude[]? // empty' "${config_file}")

  # per-job excludes (optional)
  if json_has_key "${config_file}" ".jobs[${job_index}].exclude | type == \"array\""; then
    local -a job_excludes=()
    mapfile -t job_excludes < <(jq -r ".jobs[${job_index}].exclude[]? // empty" "${config_file}")
    excludes+=("${job_excludes[@]}")
  fi

  # add excludes to args
  local pattern
  for pattern in "${excludes[@]}"; do
    args+=(--exclude="${pattern}")
  done

  log "job '${name}': rsync '${from}' -> '${to}'"
  rsync "${args[@]}" "${from}" "${to}"
}

main() {
  local config_file="${DEFAULT_CONFIG_FILE}"
  local dry_run="false"
  local verbose="false"

  if [[ "${#}" -eq 0 ]]; then
    # parameters are optional, but show help when none are provided (per your rule)
    print_help
  fi

  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
      --config)
        shift
        [[ "${#}" -gt 0 ]] || fail "--config requires a value"
        config_file="${1}"
        ;;
      --dry-run)
        dry_run="true"
        ;;
      --verbose)
        verbose="true"
        ;;
      --help)
        print_help
        exit 0
        ;;
      *)
        fail "Unknown option: ${1}"
        ;;
    esac
    shift || true
  done

  require_cmd jq
  require_cmd rsync

  [[ -f "${config_file}" ]] || fail "Config file not found: ${config_file}"

  # Validate JSON
  jq -e . "${config_file}" >/dev/null 2>&1 || fail "Invalid JSON in config: ${config_file}"

  # logging setup
  local log_dir
  log_dir="$(read_json_str "${config_file}" '.log.dir // "~/.logs/cron"')"
  log_dir="$(expand_tilde "${log_dir}")"

  local prefix
  prefix="$(read_json_str "${config_file}" '.log.filename_prefix // "download-synch"')"

  local date_fmt
  date_fmt="$(read_json_str "${config_file}" '.log.date_format // "%Y%m%d"')"

  local timestamp
  timestamp="$(date +"${date_fmt}")"

  mkdir -p "${log_dir}"

  local log_file="${log_dir}/${prefix}-${timestamp}.log"

  {
    log "download-synch start"

    # host gating
    local current_host
    current_host="$(hostname -s)"

    if json_has_key "${config_file}" '.run_on_hosts | type == "array"'; then
      if ! jq -e --arg h "${current_host}" '.run_on_hosts | index($h) != null' "${config_file}" >/dev/null 2>&1; then
        log "host gate: not allowed on '${current_host}', exiting"
        exit 0
      fi
    fi

    # default delete behaviour (can be overridden per job)
    local default_delete
    default_delete="$(read_json_bool "${config_file}" '.rsync.delete // true')"

    local jobs_len
    jobs_len="$(jq -r '.jobs | length' "${config_file}")"
    [[ "${jobs_len}" =~ ^[0-9]+$ ]] || fail "Config error: .jobs must be an array"

    if [[ "${jobs_len}" -eq 0 ]]; then
      fail "Config error: .jobs is empty"
    fi

    local i
    for ((i=0; i<jobs_len; i++)); do
      local name from to job_delete

      name="$(jq -r ".jobs[${i}].name // \"job-${i}\"" "${config_file}")"
      from="$(jq -r ".jobs[${i}].from" "${config_file}")"
      to="$(jq -r ".jobs[${i}].to" "${config_file}")"

      if [[ "${from}" == "null" || -z "${from}" ]]; then
        fail "Config error: .jobs[${i}].from missing"
      fi
      if [[ "${to}" == "null" || -z "${to}" ]]; then
        fail "Config error: .jobs[${i}].to missing"
      fi

      if json_has_key "${config_file}" ".jobs[${i}].delete"; then
        job_delete="$(read_json_bool "${config_file}" ".jobs[${i}].delete")"
      else
        job_delete="${default_delete}"
      fi

      rsync_job "${name}" "${from}" "${to}" "${job_delete}" "${dry_run}" "${verbose}" "${config_file}" "${i}"
    done

    log "download-synch done"
  } >> "${log_file}" 2>&1
}

main "${@}"
