#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<USAGE
Usage:
  ${SCRIPT_NAME} [--id <identifier> | --all] [--file <path>] [--verbose]
  ${SCRIPT_NAME} --help

Options:
  --id <identifier>   Remove exactly one issue by id.
  --all               Remove all issues.
  --file <path>       TOML file path (default: ~/.config/polybar/issues.toml).
  --verbose           Print detailed output.
  --help              Show this help.
USAGE
}

die() {
  local message="$1"
  echo "ERROR: ${message}" >&2
  usage >&2
  exit 1
}

log_setup() {
  LOG_DIR="${HOME}/.logs/polybar-issues"
  LOG_FILE="${LOG_DIR}/setup-log-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "${LOG_DIR}"
  touch "${LOG_FILE}"
}

log_info() {
  local message="$1"
  printf '%s\n' "${message}" >>"${LOG_FILE}"
  if [[ "${VERBOSE}" == "1" ]]; then
    echo "${message}" >&2
  fi
}

ID=""
REMOVE_ALL="0"
ISSUES_FILE="${HOME}/.config/polybar/issues.toml"
VERBOSE="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --help)
    usage
    exit 0
    ;;
  --id)
    shift
    [[ $# -gt 0 ]] || die "--id requires a value"
    ID="$1"
    shift
    ;;
  --all)
    REMOVE_ALL="1"
    shift
    ;;
  --file)
    shift
    [[ $# -gt 0 ]] || die "--file requires a value"
    ISSUES_FILE="$1"
    shift
    ;;
  --verbose)
    VERBOSE="1"
    shift
    ;;
  *)
    die "Unknown option: $1"
    ;;
  esac
done

if [[ "${REMOVE_ALL}" == "1" && -n "${ID}" ]]; then
  die "Use either --id or --all, not both"
fi

if [[ "${REMOVE_ALL}" == "0" && -z "${ID}" ]]; then
  die "Either --id or --all is required"
fi

log_setup
log_info "Removing issue(s) file='${ISSUES_FILE}' id='${ID}' all='${REMOVE_ALL}'"

if [[ ! -f "${ISSUES_FILE}" ]]; then
  log_info "Issue file not found, nothing to remove"
  exit 0
fi

python3 - "${ISSUES_FILE}" "${REMOVE_ALL}" "${ID}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
remove_all = sys.argv[2] == "1"
issue_id = sys.argv[3]

try:
    import tomllib
except ModuleNotFoundError as exc:
    raise SystemExit(f"ERROR: tomllib not available: {exc}")

text = path.read_text(encoding="utf-8")

try:
    doc = tomllib.loads(text) if text.strip() else {}
except Exception as exc:
    raise SystemExit(f"ERROR: unable to parse TOML: {exc}")

issues = doc.get("issue", [])
if not isinstance(issues, list):
    issues = []

if remove_all:
    issues = []
else:
    issues = [item for item in issues if not (isinstance(item, dict) and item.get("id") == issue_id)]

lines = ["# Polybar issue indicator source"]
if issues:
    lines.append("")

for item in issues:
    if not isinstance(item, dict):
        continue
    iid = str(item.get("id", "")).strip()
    if not iid:
        continue

    iprio = item.get("prio", 1)
    try:
        iprio = int(iprio)
    except Exception:
        iprio = 1
    if iprio < 1:
        iprio = 1
    if iprio > 3:
        iprio = 3

    lines.append("[[issue]]")
    lines.append(f'id = "{iid.replace(chr(34), r"\"")}"')
    lines.append(f"prio = {iprio}")

    ilabel = item.get("label", "")
    if isinstance(ilabel, str) and ilabel:
        lines.append(f'label = "{ilabel.replace(chr(34), r"\"")}"')

    idesc = item.get("description", "")
    if isinstance(idesc, str) and idesc:
        lines.append(f'description = "{idesc.replace(chr(34), r"\"")}"')

    lines.append("")

path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
PY

if [[ "${REMOVE_ALL}" == "1" ]]; then
  log_info "All issues removed from ${ISSUES_FILE}"
else
  log_info "Issue '${ID}' removed from ${ISSUES_FILE} (if it existed)"
fi
