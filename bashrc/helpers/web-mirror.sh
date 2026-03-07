#!/bin/bash
# web-mirror.sh
#
# Mirror a single web page (plus requisites) into a local, offline-browsable copy,
# then optionally compress into an archive (zip preferred, tar.gz fallback).
#
# Requires: wget
# Optional: zip (preferred) or tar+gzip (fallback)

set -euo pipefail
IFS=$'\n\t'

print_help() {
  local script_name
  script_name="$(basename "${0}")"

  cat <<'EOF'
Mirror a webpage with assets for offline use, optionally compressing the result.

Usage:
  SCRIPT_NAME --url "https://example.com/page" [--compress true|false] [--verbose]

Required:
  --url                 Website URL to mirror

Optional:
  --compress            true by default. If true, creates an archive and removes the folder (unless --keep-folder).
  --keep-folder         If --compress true, keep the mirrored folder after archiving.
  --output              Output name (base). Default: derived from hostname + timestamp.
  --verbose             More output.
  --help                Show this help.

Notes:
  * Uses wget mirroring features:
    - downloads page requisites (CSS/JS/images)
    - converts links for offline browsing
    - adjusts extensions to .html where appropriate

Examples:
  SCRIPT_NAME --url "https://example.com"
  SCRIPT_NAME --url "https://example.com/docs/page" --compress false
  SCRIPT_NAME --url "https://example.com" --compress true --keep-folder --verbose
EOF
}

log_init() {
  mkdir -p "${HOME}/.logs"
  local ts
  ts="$(date +"%Y%m%d-%H%M%S")"
  LOG_FILE="${HOME}/.logs/setup-log-${ts}.log"
  touch "${LOG_FILE}"
}

log() {
  local msg
  msg="${1}"
  printf '%s %s\n' "$(date +"%Y-%m-%d %H:%M:%S")" "${msg}" >>"${LOG_FILE}"

  if [[ "${VERBOSE}" == "true" ]]; then
    printf '%s\n' "${msg}"
  fi
}

die() {
  local msg
  msg="${1}"
  log "ERROR: ${msg}"
  printf 'ERROR: %s\n\n' "${msg}" >&2
  print_help | sed "s/SCRIPT_NAME/$(basename "${0}")/g" >&2
  exit 1
}

require_cmd() {
  local cmd
  cmd="${1}"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    die "Missing required command: ${cmd}"
  fi
}

safe_slug() {
  # Turn arbitrary text into a safe-ish folder name
  # shellcheck disable=SC2001
  echo "${1}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g' | sed 's/--\+/-/g'
}

pick_archiver() {
  if command -v zip >/dev/null 2>&1; then
    echo "zip"
    return 0
  fi
  if command -v tar >/dev/null 2>&1; then
    echo "tar.gz"
    return 0
  fi
  return 1
}

# Defaults
URL=""
COMPRESS="true"
KEEP_FOLDER="false"
OUTPUT_BASENAME=""
VERBOSE="false"
LOG_FILE=""

# If no args: show help (but still exit non-zero because URL is required)
if [[ "${#}" -eq 0 ]]; then
  print_help | sed "s/SCRIPT_NAME/$(basename "${0}")/g"
  exit 1
fi

# Parse args
while [[ "${#}" -gt 0 ]]; do
  case "${1}" in
  --url)
    URL="${2:-}"
    shift 2
    ;;
  --compress)
    COMPRESS="${2:-}"
    shift 2
    ;;
  --keep-folder)
    KEEP_FOLDER="true"
    shift 1
    ;;
  --output)
    OUTPUT_BASENAME="${2:-}"
    shift 2
    ;;
  --verbose)
    VERBOSE="true"
    shift 1
    ;;
  --help)
    print_help | sed "s/SCRIPT_NAME/$(basename "${0}")/g"
    exit 0
    ;;
  *)
    die "Unknown argument: ${1}"
    ;;
  esac
done

log_init
log "Starting web mirror"
log "URL='${URL}' compress='${COMPRESS}' keep_folder='${KEEP_FOLDER}' verbose='${VERBOSE}'"

[[ -n "${URL}" ]] || die "Missing --url"

# Basic URL sanity check
if [[ "${URL}" != http://* && "${URL}" != https://* ]]; then
  die "--url must start with http:// or https://"
fi

# Requirements
require_cmd "wget"

# Derive a default output name from hostname + timestamp (in current directory)
host="$(echo "${URL}" | awk -F/ '{print $3}' | awk -F: '{print $1}')"
if [[ -z "${host}" ]]; then
  host="site"
fi
host_slug="$(safe_slug "${host}")"
ts="$(date +"%Y%m%d-%H%M%S")"

if [[ -n "${OUTPUT_BASENAME}" ]]; then
  base="$(safe_slug "${OUTPUT_BASENAME}")"
else
  base="mirror-${host_slug}-${ts}"
fi

OUTDIR="${PWD}/${base}"
log "Output directory: ${OUTDIR}"

if [[ -e "${OUTDIR}" ]]; then
  die "Output path already exists: ${OUTDIR}"
fi

mkdir -p "${OUTDIR}"

# wget mirroring:
# --mirror            : recursive mirroring (equiv to -r -N -l inf --no-remove-listing)
# --page-requisites   : get all assets needed to display the page
# --convert-links     : rewrite links for offline viewing
# --adjust-extension  : save HTML/CSS files with proper extensions
# --no-parent         : don't ascend to parent directories
# --directory-prefix  : put everything under OUTDIR
#
# Note: by default, wget downloads requisites on other hosts that are needed for the page,
# but it will not recursively mirror those hosts' other pages. This is usually what you want.
log "Running wget mirror"

set +e
wget \
  --server-response \
  --content-on-error \
  --mirror \
  --page-requisites \
  --convert-links \
  --adjust-extension \
  --no-parent \
  --directory-prefix="${OUTDIR}" \
  "${URL}" >>"${LOG_FILE}" 2>&1
wget_rc="${?}"
set -e

# Detect empty mirror result (no files)
if ! find "${OUTDIR}" -type f -mindepth 1 -print -quit | grep -q '.'; then
  die "Mirror folder is empty. The site likely blocked the request or redirected to login. Log: ${LOG_FILE}"
fi

log "wget completed"

if [[ "${COMPRESS}" != "true" && "${COMPRESS}" != "false" ]]; then
  die "--compress must be 'true' or 'false'"
fi

if [[ "${COMPRESS}" == "false" ]]; then
  log "Compression disabled. Folder kept at: ${OUTDIR}"
  printf '%s\n' "${OUTDIR}"
  exit 0
fi

archiver="$(pick_archiver || true)"
if [[ -z "${archiver}" ]]; then
  die "Compression requested but neither 'zip' nor 'tar' is available"
fi

if [[ "${archiver}" == "zip" ]]; then
  ARCHIVE_PATH="${PWD}/${base}.zip"
  log "Creating zip archive: ${ARCHIVE_PATH}"
  (cd "${PWD}" && zip -r "${ARCHIVE_PATH}" "${base}" >>"${LOG_FILE}" 2>&1)
else
  ARCHIVE_PATH="${PWD}/${base}.tar.gz"
  log "Creating tar.gz archive: ${ARCHIVE_PATH}"
  (cd "${PWD}" && tar -czf "${ARCHIVE_PATH}" "${base}" >>"${LOG_FILE}" 2>&1)
fi

log "Archive created: ${ARCHIVE_PATH}"

if [[ "${KEEP_FOLDER}" == "true" ]]; then
  log "Keeping folder (per --keep-folder): ${OUTDIR}"
else
  log "Removing folder (default behaviour when compressing): ${OUTDIR}"
  rm -rf "${OUTDIR}"
fi

printf '%s\n' "${ARCHIVE_PATH}"
