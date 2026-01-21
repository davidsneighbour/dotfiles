#!/bin/bash
# shellcheck disable=SC2034

# dnb_config_get: Read config values from a TOML file
# Contract (collision-safe):
# * Found: prints value, exit 0
# * Missing/unset/empty: prints nothing (unless --print-fallback), exit 1
# * Parse error / env error: prints nothing (unless --print-fallback), exit 2

dnb_config_get() {
  local func="${FUNCNAME[0]}"

  local file_path=""
  local query=""

  local opt_help="false"
  local opt_list_keys="false"
  local opt_fail_on_unset="false"
  local opt_fail_on_empty="false"
  local opt_trim_values="false"
  local opt_print_fallback=""

  if [[ "${#}" -eq 0 ]]; then
    opt_help="true"
  else
    while [[ "${#}" -gt 0 ]]; do
      case "${1}" in
        --help|-h) opt_help="true"; shift ;;
        --list-keys) opt_list_keys="true"; shift ;;
        --file)
          shift
          [[ "${#}" -eq 0 ]] && opt_help="true" && break
          file_path="${1}"; shift
          ;;
        --fail-on-unset) opt_fail_on_unset="true"; shift ;;
        --fail-on-empty) opt_fail_on_empty="true"; shift ;;
        --trim-values) opt_trim_values="true"; shift ;;
        --print-fallback)
          shift
          [[ "${#}" -eq 0 ]] && opt_help="true" && break
          opt_print_fallback="${1}"; shift
          ;;
        -*) opt_help="true"; shift ;;
        *)
          [[ -z "${query}" ]] && query="${1}" || opt_help="true"
          shift
          ;;
      esac
    done
  fi

  if [[ "${opt_help}" == "true" ]]; then
    cat <<EOF
Usage:
  ${func} --file <path> <key.path> [options]
  ${func} --file <path> --list-keys
  ${func} --help
EOF
    return 0
  fi

  [[ -z "${file_path}" ]] && { [[ -n "${opt_print_fallback}" ]] && printf '%s\n' "${opt_print_fallback}"; return 1; }
  [[ "${opt_list_keys}" == "false" && -z "${query}" ]] && { [[ -n "${opt_print_fallback}" ]] && printf '%s\n' "${opt_print_fallback}"; return 1; }
  [[ ! -f "${file_path}" ]] && { [[ -n "${opt_print_fallback}" ]] && printf '%s\n' "${opt_print_fallback}"; return 1; }

  local py_out=""
  local py_exit="0"

  py_out="$(
    python3 - "${file_path}" "${query}" "${opt_list_keys}" "${opt_fail_on_empty}" "${opt_trim_values}" <<'PY'
import sys
from pathlib import Path

def require_py311():
  if sys.version_info < (3, 11):
    raise RuntimeError("Python 3.11+ is required")

def load_toml(text):
  require_py311()
  import tomllib
  return tomllib.loads(text)

def split_path(p):
  return [s for s in p.split(".") if s]

def get_value(doc, path):
  cur = doc
  for seg in path:
    if not isinstance(cur, dict) or seg not in cur:
      return None
    cur = cur[seg]
  return cur

def is_scalar(v):
  return isinstance(v, (str, int, float, bool))

def trim(s):
  return s.strip()

def list_keys(doc):
  out = []
  def walk(node, prefix):
    if isinstance(node, dict):
      for k, v in node.items():
        walk(v, prefix + [str(k)])
    elif isinstance(node, list) or is_scalar(node):
      out.append(".".join(prefix))
  walk(doc, [])
  return sorted(out)

def print_value(v, fail_on_empty, trim_values):
  if v is None or isinstance(v, dict):
    return 1

  if isinstance(v, list):
    if fail_on_empty and not v:
      return 1
    for item in v:
      if not is_scalar(item):
        return 1
      if isinstance(item, str):
        s = trim(item) if trim_values else item
        if fail_on_empty and not s:
          return 1
        print(s)
      else:
        print(item)
    return 0

  if is_scalar(v):
    if isinstance(v, str):
      s = trim(v) if trim_values else v
      if fail_on_empty and not s:
        return 1
      sys.stdout.write(s)
      if s:
        sys.stdout.write("\n")
      return 0
    print("true" if v is True else "false" if v is False else v)
    return 0

  return 1

def main():
  path = Path(sys.argv[1])
  query = sys.argv[2]
  opt_list = sys.argv[3] == "true"
  fail_on_empty = sys.argv[4] == "true"
  trim_values = sys.argv[5] == "true"

  try:
    doc = load_toml(path.read_text(encoding="utf-8"))
  except Exception as e:
    print(e, file=sys.stderr)
    return 2

  if opt_list:
    for k in list_keys(doc):
      print(k)
    return 0

  v = get_value(doc, split_path(query))
  return print_value(v, fail_on_empty, trim_values)

raise SystemExit(main())
PY
  )"
  py_exit="${?}"

  if [[ "${py_exit}" -eq 0 ]]; then
    printf '%s' "${py_out}"
    return 0
  fi

  [[ -n "${opt_print_fallback}" ]] && printf '%s\n' "${opt_print_fallback}"
  [[ "${py_exit}" -eq 2 ]] && return 2
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dnb_config_get "$@"
  exit "${?}"
fi
