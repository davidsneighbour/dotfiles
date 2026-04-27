#!/bin/bash

set -euo pipefail

DEFAULT_DOCKER_PATH="${HOME}/.dotfiles/containers/locutus"
DEFAULT_BACKUP_PATH="/mnt/storage/Backup/Docker/Locutus"
DEFAULT_KEEP_COUNT="7"

DOCKER_PATH="${DEFAULT_DOCKER_PATH}"
BACKUP_PATH="${DEFAULT_BACKUP_PATH}"
KEEP_COUNT="${DEFAULT_KEEP_COUNT}"
KEEP_BACKUP="false"
DRY_RUN="false"
VERBOSE="false"

SCRIPT_NAME="$(basename "$0")"
TODAY="$(date +%Y%m%d)"
LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Back up Docker Compose container folders one by one.

Options:
  --docker-path PATH     Docker directory containing container subfolders.
                         Default: ${DEFAULT_DOCKER_PATH}

  --backup-path PATH     Backup root directory.
                         Default: ${DEFAULT_BACKUP_PATH}

  --keep-count NUMBER    Number of normal dated backups to keep.
                         Default: ${DEFAULT_KEEP_COUNT}

  --keep                 Create a keep backup named yyyymmdd-keep.
                         Keep backups are excluded from rotation.

  --dry-run              Print actions without changing containers or files.

  --verbose              Print detailed progress.

  --help                 Show this help.

Examples:
  ${SCRIPT_NAME}

  ${SCRIPT_NAME} --keep

  ${SCRIPT_NAME} --docker-path "${HOME}/.dotfiles/containers/locutus" \\
    --backup-path "/mnt/storage/Backup/Docker/Locutus" \\
    --keep-count 7
EOF
}

log_info() {
  echo "[info] $*"
}

log_warn() {
  echo "[warn] $*" >&2
}

log_error() {
  echo "[error] $*" >&2
}

log_verbose() {
  if [[ "${VERBOSE}" == "true" ]]; then
    echo "[debug] $*"
  fi
}

require_command() {
  local command_name="${1}"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log_error "Missing required command: ${command_name}"
    exit 1
  fi
}

has_compose_file() {
  local directory="${1}"

  [[ -f "${directory}/compose.yml" ]] ||
    [[ -f "${directory}/compose.yaml" ]] ||
    [[ -f "${directory}/docker-compose.yml" ]] ||
    [[ -f "${directory}/docker-compose.yaml" ]]
}

run_command() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

rotate_backups() {
  local container_backup_path="${1}"
  local keep_count="${2}"

  mapfile -t normal_backups < <(
    find "${container_backup_path}" \
      -mindepth 1 \
      -maxdepth 1 \
      -type d \
      -regextype posix-extended \
      -regex '.*/[0-9]{8}$' \
      -printf '%f\n' |
      sort -r
  )

  local index="0"
  local backup_name

  for backup_name in "${normal_backups[@]}"; do
    index=$((index + 1))

    if ((index > keep_count)); then
      log_info "Removing rotated backup: ${container_backup_path}/${backup_name}"
      run_command rm -rf -- "${container_backup_path:?}/${backup_name}"
    fi
  done
}

backup_container_folder() {
  local container_path="${1}"
  local container_name
  local backup_name
  local container_backup_root
  local container_backup_path

  container_name="$(basename "${container_path}")"

  if [[ "${KEEP_BACKUP}" == "true" ]]; then
    backup_name="${TODAY}-keep"
  else
    backup_name="${TODAY}"
  fi

  container_backup_root="${BACKUP_PATH}/${container_name}"
  container_backup_path="${container_backup_root}/${backup_name}"

  log_info "Backing up container folder: ${container_name}"

  run_command mkdir -p -- "${container_backup_root}"

  log_verbose "Stopping Docker Compose stack in ${container_path}"
  run_command docker compose --project-directory "${container_path}" down

  local backup_failed="false"

  {
    log_verbose "Replacing existing same-day backup: ${container_backup_path}"
    run_command rm -rf -- "${container_backup_path}"
    run_command mkdir -p -- "${container_backup_path}"

    log_verbose "Running rsync into ${container_backup_path}"
    run_command rsync \
      -aHAX \
      --numeric-ids \
      --delete \
      "${container_path}/" \
      "${container_backup_path}/"
  } || {
    backup_failed="true"
    log_error "Backup failed for ${container_name}"
  }

  log_verbose "Starting Docker Compose stack in ${container_path}"
  run_command docker compose --project-directory "${container_path}" up -d

  if [[ "${backup_failed}" == "true" ]]; then
    return 1
  fi

  if [[ "${KEEP_BACKUP}" != "true" ]]; then
    rotate_backups "${container_backup_root}" "${KEEP_COUNT}"
  fi
}

parse_args() {
  while (($# > 0)); do
    case "${1}" in
    --docker-path)
      DOCKER_PATH="${2:-}"
      shift 2
      ;;
    --backup-path)
      BACKUP_PATH="${2:-}"
      shift 2
      ;;
    --keep-count)
      KEEP_COUNT="${2:-}"
      shift 2
      ;;
    --keep)
      KEEP_BACKUP="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --verbose)
      VERBOSE="true"
      shift
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      log_error "Unknown option: ${1}"
      print_help
      exit 1
      ;;
    esac
  done
}

main() {
  parse_args "$@"

  require_command docker
  require_command rsync
  require_command find
  require_command flock

  if [[ ! -d "${DOCKER_PATH}" ]]; then
    log_error "Docker path does not exist: ${DOCKER_PATH}"
    print_help
    exit 1
  fi

  run_command mkdir -p -- "${BACKUP_PATH}"

  exec 9>"${LOCK_FILE}"
  if ! flock -n 9; then
    log_error "Another backup is already running: ${LOCK_FILE}"
    exit 1
  fi

  local container_path
  local failed_count="0"

  while IFS= read -r -d '' container_path; do
    if has_compose_file "${container_path}"; then
      if ! backup_container_folder "${container_path}"; then
        failed_count=$((failed_count + 1))
      fi
    else
      log_verbose "Skipping folder without Docker Compose file: ${container_path}"
    fi
  done < <(find "${DOCKER_PATH}" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

  if ((failed_count > 0)); then
    log_error "Finished with ${failed_count} failed backup(s)."
    exit 1
  fi

  log_info "Docker folder backup completed."
}

main "$@"
