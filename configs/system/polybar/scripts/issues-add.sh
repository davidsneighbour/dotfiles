#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<USAGE
Usage:
  ${SCRIPT_NAME} --id <identifier> [--prio <1|2|3>] [--label <text>] [--description <text>] [--file <path>] [--verbose]
  ${SCRIPT_NAME} --help

Options:
  --id <identifier>      Required unique issue id.
  --prio <1|2|3>         Priority (1=high, 2=medium, 3=notice). Default: 1.
  --label <text>         Optional short label (max 24 chars).
  --description <text>   Optional long description.
  --file <path>          TOML file path (default: ~/.config/polybar/issues.toml).
  --verbose              Print detailed output.
  --help                 Show this help.
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
PRIO="1"
LABEL=""
DESCRIPTION=""
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
  --prio)
    shift
    [[ $# -gt 0 ]] || die "--prio requires a value"
    PRIO="$1"
    shift
    ;;
  --label)
    shift
    [[ $# -gt 0 ]] || die "--label requires a value"
    LABEL="$1"
    shift
    ;;
  --description)
    shift
    [[ $# -gt 0 ]] || die "--description requires a value"
    DESCRIPTION="$1"
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

[[ -n "${ID}" ]] || die "--id is required"
[[ "${PRIO}" =~ ^[1-3]$ ]] || die "--prio must be 1, 2, or 3"

if [[ ${#LABEL} -gt 24 ]]; then
  die "--label must be 24 characters or fewer"
fi

log_setup
log_info "Adding/updating issue id='${ID}' prio='${PRIO}' file='${ISSUES_FILE}'"

mkdir -p "$(dirname "${ISSUES_FILE}")"
if [[ ! -f "${ISSUES_FILE}" ]]; then
  cat >"${ISSUES_FILE}" <<'TOML'
# Polybar issue indicator source
TOML
fi

python3 - "${ISSUES_FILE}" "${ID}" "${PRIO}" "${LABEL}" "${DESCRIPTION}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
issue_id = sys.argv[2]
prio = int(sys.argv[3])
label = sys.argv[4]
description = sys.argv[5]

try:
    import tomllib
except ModuleNotFoundError as exc:
    raise SystemExit(f"ERROR: tomllib not available: {exc}")

text = path.read_text(encoding="utf-8") if path.exists() else ""

try:
    doc = tomllib.loads(text) if text.strip() else {}
except Exception as exc:
    raise SystemExit(f"ERROR: unable to parse TOML: {exc}")

issues = doc.get("issue", [])
if not isinstance(issues, list):
    issues = []

new_issue = {"id": issue_id, "prio": prio}
if label:
    new_issue["label"] = label
if description:
    new_issue["description"] = description

updated = False
for idx, item in enumerate(issues):
    if isinstance(item, dict) and item.get("id") == issue_id:
        issues[idx] = new_issue
        updated = True
        break

if not updated:
    issues.append(new_issue)

lines = ["# Polybar issue indicator source", ""]
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

log_info "Issue '${ID}' written to ${ISSUES_FILE}"
