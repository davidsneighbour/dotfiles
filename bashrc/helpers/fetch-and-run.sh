#!/bin/bash
# shellcheck shell=bash
#
# fetch-and-run.sh
#
# Download a remote installer script to a temp file, optionally verify its
# sha256 checksum, and execute it explicitly instead of piping curl directly
# into a shell.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
URL=""
SHA256=""
INTERPRETER="sh"
DRY_RUN=false
VERBOSE=false

log() {
  local level="${1:-INFO}"
  shift || true
  printf '[%s] %s\n' "${level}" "${*:-}"
}

vlog() {
  if [[ "${VERBOSE}" == true ]]; then
    log "DEBUG" "$@"
  fi
}

die() {
  log "ERROR" "$*" >&2
  exit 1
}

print_help() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} --url <URL> [--sha256 <hex>] [--interpreter sh|bash] [--dry-run] [--verbose] [--help]

Download a remote installer to a temp file and run it explicitly, instead of
piping curl straight into a shell.

Options:
  --url <URL>           Required. Installer URL to download.
  --sha256 <hex>         Expected sha256 checksum of the downloaded file.
                         Aborts if the actual checksum does not match.
  --interpreter sh|bash  Interpreter to run the downloaded script with.
                         Default: sh.
  --dry-run              Print what would be downloaded and run, without
                         downloading or executing anything.
  --verbose               Print the download location and a content preview
                         before running.
  --help                  Show this help output.

Notes:
  When --sha256 is not given, this prints a warning and proceeds on HTTPS
  trust alone, since some upstream installers do not publish a checksum for
  their install script.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
  --url)
    URL="${2:-}"
    shift 2
    ;;
  --sha256)
    SHA256="${2:-}"
    shift 2
    ;;
  --interpreter)
    INTERPRETER="${2:-}"
    shift 2
    ;;
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  --verbose)
    VERBOSE=true
    shift
    ;;
  --help)
    print_help
    exit 0
    ;;
  *)
    die "Unknown argument: ${1}. Run with --help for usage."
    ;;
  esac
done

if [[ -z "${URL}" ]]; then
  print_help
  die "--url is required."
fi

if [[ "${INTERPRETER}" != "sh" && "${INTERPRETER}" != "bash" ]]; then
  die "--interpreter must be 'sh' or 'bash'."
fi

if [[ "${DRY_RUN}" == true ]]; then
  log "INFO" "Would download: ${URL}"
  if [[ -n "${SHA256}" ]]; then
    log "INFO" "Would verify sha256: ${SHA256}"
  else
    log "INFO" "No sha256 provided; would proceed on HTTPS trust alone."
  fi
  log "INFO" "Would execute with: ${INTERPRETER}"
  exit 0
fi

TMP_FILE="$(mktemp)"
cleanup() {
  rm -f "${TMP_FILE}"
}
trap cleanup EXIT

vlog "Downloading ${URL} to ${TMP_FILE}"

if ! curl --proto '=https' --tlsv1.2 -fsSL "${URL}" -o "${TMP_FILE}"; then
  die "Failed to download ${URL}."
fi

if [[ -n "${SHA256}" ]]; then
  ACTUAL_SHA256="$(sha256sum "${TMP_FILE}" | cut -d' ' -f1)"
  if [[ "${ACTUAL_SHA256}" != "${SHA256}" ]]; then
    die "Checksum mismatch for ${URL}: expected ${SHA256}, got ${ACTUAL_SHA256}."
  fi
  vlog "Checksum verified: ${ACTUAL_SHA256}"
else
  log "WARN" "No sha256 provided for ${URL}; proceeding on HTTPS trust alone."
fi

log "INFO" "Downloaded to ${TMP_FILE}; running with ${INTERPRETER}."
if [[ "${VERBOSE}" == true ]]; then
  log "DEBUG" "Preview (first 10 lines):"
  head -n 10 "${TMP_FILE}"
fi

"${INTERPRETER}" "${TMP_FILE}"
