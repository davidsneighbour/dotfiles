# shellcheck shell=bash

# dnb_polybar_issue_add
#
# Add or update an issue entry in a TOML issue source file.
#
# Usage:
#   dnb_polybar_issue_add --id <identifier> [--prio <1|2|3>] [--label <text>] [--description <text>] [--file <path>] [--log-file <path>] [--verbose]
#   dnb_polybar_issue_add --help
#
# Returns:
#   0 on success, non-zero on validation or write failure.
dnb_polybar_issue_add() {
  local id=''
  local prio='1'
  local label=''
  local description=''
  local issues_file="${DNB_POLYBAR_ISSUES_FILE:-${HOME}/.config/polybar/issues.toml}"
  local verbose='0'
  local log_file="${DNB_POLYBAR_ISSUES_LOG_FILE:-}"

  if [[ "$#" -eq 0 || "${1:-}" == '--help' ]]; then
    cat <<EOF2
${FUNCNAME[0]} - add or update a polybar issue

Usage:
  ${FUNCNAME[0]} --id <identifier> [--prio <1|2|3>] [--label <text>] [--description <text>] [--file <path>] [--log-file <path>] [--verbose]
  ${FUNCNAME[0]} --help
EOF2
    return 0
  fi

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    --id)
      shift
      [[ "$#" -gt 0 ]] || {
        echo "ERROR: --id requires a value" >&2
        return 1
      }
      id="${1}"
      shift
      ;;
    --prio)
      shift
      [[ "$#" -gt 0 ]] || {
        echo "ERROR: --prio requires a value" >&2
        return 1
      }
      prio="${1}"
      shift
      ;;
    --label)
      shift
      [[ "$#" -gt 0 ]] || {
        echo "ERROR: --label requires a value" >&2
        return 1
      }
      label="${1}"
      shift
      ;;
    --description)
      shift
      [[ "$#" -gt 0 ]] || {
        echo "ERROR: --description requires a value" >&2
        return 1
      }
      description="${1}"
      shift
      ;;
    --file)
      shift
      [[ "$#" -gt 0 ]] || {
        echo "ERROR: --file requires a value" >&2
        return 1
      }
      issues_file="${1}"
      shift
      ;;
    --log-file)
      shift
      [[ "$#" -gt 0 ]] || {
        echo "ERROR: --log-file requires a value" >&2
        return 1
      }
      log_file="${1}"
      shift
      ;;
    --verbose)
      verbose='1'
      shift
      ;;
    *)
      echo "ERROR: Unknown option: ${1}" >&2
      return 1
      ;;
    esac
  done

  [[ -n "${id}" ]] || {
    echo 'ERROR: --id is required' >&2
    return 1
  }
  [[ "${prio}" =~ ^[1-3]$ ]] || {
    echo 'ERROR: --prio must be 1, 2, or 3' >&2
    return 1
  }
  if [[ "${#label}" -gt 24 ]]; then
    echo 'ERROR: --label must be 24 characters or fewer' >&2
    return 1
  fi

  mkdir -p "$(dirname "${issues_file}")"
  if [[ ! -f "${issues_file}" ]]; then
    cat >"${issues_file}" <<'TOML'
# Polybar issue indicator source
TOML
  fi

  if [[ -n "${log_file}" ]]; then
    mkdir -p "$(dirname "${log_file}")"
    touch "${log_file}"
    printf "Adding/updating issue id='%s' prio='%s' file='%s'\n" "${id}" "${prio}" "${issues_file}" >>"${log_file}"
  fi

  python3 - "${issues_file}" "${id}" "${prio}" "${label}" "${description}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
issue_id = sys.argv[2]
prio = int(sys.argv[3])
label = sys.argv[4]
description = sys.argv[5]

import tomllib

text = path.read_text(encoding="utf-8") if path.exists() else ""
doc = tomllib.loads(text) if text.strip() else {}
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
    iprio = min(max(iprio, 1), 3)

    lines.append("[[issue]]")
    lines.append(f'id = "{iid.replace(chr(34), r"\\\"")}"')
    lines.append(f"prio = {iprio}")

    ilabel = item.get("label", "")
    if isinstance(ilabel, str) and ilabel:
        lines.append(f'label = "{ilabel.replace(chr(34), r"\\\"")}"')

    idesc = item.get("description", "")
    if isinstance(idesc, str) and idesc:
        lines.append(f'description = "{idesc.replace(chr(34), r"\\\"")}"')

    lines.append("")

path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
PY
  local py_exit_code="$?"
  if [[ "${py_exit_code}" -ne 0 ]]; then
    echo "ERROR: failed to write issue '${id}' to ${issues_file}" >&2
    return "${py_exit_code}"
  fi

  if [[ "${verbose}" == '1' ]]; then
    echo "Issue '${id}' written to ${issues_file}" >&2
  fi

  if [[ -n "${log_file}" ]]; then
    printf "Issue '%s' written to %s\n" "${id}" "${issues_file}" >>"${log_file}"
  fi

  return 0
}

# dnb_msgvault_add_polybar_issue
#
# Add a msgvault sync failure issue via dnb_polybar_issue_add.
#
# Usage:
#   dnb_msgvault_add_polybar_issue --reason <text> [--log-file <path>] [--issue-id <id>] [--issues-file <path>] [--verbose]
#   dnb_msgvault_add_polybar_issue --help
dnb_msgvault_add_polybar_issue() {
  local failure_reason=''
  local log_file=''
  local issue_id="${DNB_MSGVAULT_POLYBAR_ISSUE_ID:-msgvault-sync}"
  local issues_file="${DNB_POLYBAR_ISSUES_FILE:-${HOME}/.config/polybar/issues.toml}"
  local verbose='0'

  if [[ "$#" -eq 0 || "${1:-}" == '--help' ]]; then
    cat <<EOF2
${FUNCNAME[0]} - add msgvault failure issue

Usage:
  ${FUNCNAME[0]} --reason <text> [--log-file <path>] [--issue-id <id>] [--issues-file <path>] [--verbose]
  ${FUNCNAME[0]} --help
EOF2
    return 0
  fi

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    --reason)
      shift
      [[ "$#" -gt 0 ]] || {
        echo 'ERROR: --reason requires a value' >&2
        return 1
      }
      failure_reason="${1}"
      shift
      ;;
    --log-file)
      shift
      [[ "$#" -gt 0 ]] || {
        echo 'ERROR: --log-file requires a value' >&2
        return 1
      }
      log_file="${1}"
      shift
      ;;
    --issue-id)
      shift
      [[ "$#" -gt 0 ]] || {
        echo 'ERROR: --issue-id requires a value' >&2
        return 1
      }
      issue_id="${1}"
      shift
      ;;
    --issues-file)
      shift
      [[ "$#" -gt 0 ]] || {
        echo 'ERROR: --issues-file requires a value' >&2
        return 1
      }
      issues_file="${1}"
      shift
      ;;
    --verbose)
      verbose='1'
      shift
      ;;
    *)
      echo "ERROR: Unknown option: ${1}" >&2
      return 1
      ;;
    esac
  done

  [[ -n "${failure_reason}" ]] || {
    echo 'ERROR: --reason is required' >&2
    return 1
  }

  local -a issue_add_args=(
    --id "${issue_id}"
    --prio "1"
    --label "msgvault sync failed"
    --description "${failure_reason}. Log: ${log_file}"
    --file "${issues_file}"
    --log-file "${log_file}"
  )

  if [[ "${verbose}" == "1" ]]; then
    issue_add_args+=(--verbose)
  fi

  dnb_polybar_issue_add "${issue_add_args[@]}"
}
