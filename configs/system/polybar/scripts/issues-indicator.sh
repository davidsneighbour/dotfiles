#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<USAGE
Usage:
  ${SCRIPT_NAME} [--file <path>] [--show-ok] [--verbose]
  ${SCRIPT_NAME} --help

Options:
  --file <path>   TOML file to read (default: ~/.config/polybar/issues.toml).
  --show-ok       Show a green checkmark when no issues exist.
  --verbose       Alias for --show-ok.
  --help          Show this help.
USAGE
}

ISSUES_FILE="${HOME}/.config/polybar/issues.toml"
SHOW_OK="${POLYBAR_ISSUES_SHOW_OK:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --help)
    usage
    exit 0
    ;;
  --file)
    shift
    [[ $# -gt 0 ]] || {
      echo "ERROR: --file requires a value" >&2
      usage >&2
      exit 1
    }
    ISSUES_FILE="$1"
    shift
    ;;
  --show-ok|--verbose)
    SHOW_OK="1"
    shift
    ;;
  *)
    echo "ERROR: Unknown option: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
done

if [[ ! -f "${ISSUES_FILE}" ]]; then
  if [[ "${SHOW_OK}" == "1" ]]; then
    printf '%%{F#50fa7b}✓%%{F-}\n'
  fi
  exit 0
fi

parse_result="$({ python3 - "${ISSUES_FILE}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    import tomllib
except ModuleNotFoundError:
    print("ERR|tomllib not available", end="")
    raise SystemExit(0)

try:
    data = tomllib.loads(path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"ERR|{exc}", end="")
    raise SystemExit(0)

issues = data.get("issue", [])
if not isinstance(issues, list):
    issues = []

if len(issues) == 0:
    print("OK|0", end="")
    raise SystemExit(0)

min_prio = 3
for item in issues:
    if not isinstance(item, dict):
        continue
    prio = item.get("prio", 1)
    try:
        prio = int(prio)
    except Exception:
        prio = 1
    if prio < 1:
        prio = 1
    if prio > 3:
        prio = 3
    if prio < min_prio:
        min_prio = prio

print(f"ISSUES|{len(issues)}|{min_prio}", end="")
PY
} 2>/dev/null)"

case "${parse_result}" in
OK\|0)
  if [[ "${SHOW_OK}" == "1" ]]; then
    printf '%%{F#50fa7b}✓%%{F-}\n'
  fi
  ;;
ISSUES\|*)
  IFS='|' read -r _ issue_count min_prio <<<"${parse_result}"
  color="#ff5555"
  if [[ "${min_prio}" == "2" ]]; then
    color="#f1c40f"
  elif [[ "${min_prio}" == "3" ]]; then
    color="#50fa7b"
  fi
  printf '%%{F%s}●%%{F-} %s\n' "${color}" "${issue_count}"
  ;;
*)
  # Fail closed (hide output) unless verbose/show-ok is requested.
  if [[ "${SHOW_OK}" == "1" ]]; then
    printf '%%{F#50fa7b}✓%%{F-}\n'
  fi
  ;;
esac
