#!/bin/bash
# shellcheck disable=SC2034

# dnb_repo_config_get: Read repo-local TOML config from <repo>/.github/dnb.toml
# Contract:
# * Found: prints value, exit 0 (empty string prints empty)
# * Missing file or key or not a git repo: prints "false", exit 1
# * Invalid TOML / parser error: prints "false", stderr message, exit 2

dnb_repo_config_get() {
  local func="${FUNCNAME[0]}"
  local query=""
  local opt_help="false"
  local opt_list_keys="false"

  # If no params given, always print help.
  if [[ "${#}" -eq 0 ]]; then
    opt_help="true"
  else
    # Parse args: allow "<path> [--help] [--list-keys]" or "--help" / "--list-keys"
    while [[ "${#}" -gt 0 ]]; do
      case "${1}" in
        --help|-h)
          opt_help="true"
          shift
          ;;
        --list-keys)
          opt_list_keys="true"
          shift
          ;;
        -*)
          printf '%s\n' "Error: Unknown option: ${1}" >&2
          opt_help="true"
          shift
          ;;
        *)
          if [[ -z "${query}" ]]; then
            query="${1}"
          else
            printf '%s\n' "Error: Unexpected argument: ${1}" >&2
            opt_help="true"
          fi
          shift
          ;;
      esac
    done
  fi

  if [[ "${opt_help}" == "true" ]]; then
    cat <<EOF
Usage:
  ${func} <path>
  ${func} --list-keys
  ${func} --help

Description:
  Reads repository-local configuration from <repo>/.github/dnb.toml and returns the value
  for a dotted key path (for example: launcher.icon or meta.social.bluesky).

Resolution:
  * Repo root is determined via: git rev-parse --show-toplevel
  * Config file path: <repo>/.github/dnb.toml
  * Missing repo/config/key prints "false" and exits 1.

Path rules:
  * Path segments are split on "." (dot).
  * Keys containing literal dots are not supported (avoid quoted TOML keys with dots).

Output formatting:
  * string: printed as-is (empty string prints empty)
  * int/float/bool: printed as a plain scalar
  * array: each item printed on its own line
  * table/object: not returned (prints "false")

Schema (documented contract, informational):
  launcher.icon        (string)
    Icon identifier for your launcher.

  launcher.name        (string, optional)
    Human-readable name override.

  launcher.group       (string, optional)
    Launcher grouping/category.

  repo.role            (string)
    One of: dotfiles, client, product, lab, archive

  repo.visibility      (string)
    One of: public, private

  repo.notes           (string, optional)
    Short freeform description.

Exit codes:
  0  Key found
  1  Key/config/repo not found
  2  TOML parse error or missing parser support

Examples:
  ${func} launcher.icon
  ${func} repo.role
  ${func} --list-keys
EOF
    return 0
  fi

  if [[ "${opt_list_keys}" == "false" && -z "${query}" ]]; then
    printf '%s\n' "false"
    return 1
  fi

  # Determine repo root (quietly).
  local repo_root=""
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || true
  if [[ -z "${repo_root}" ]]; then
    printf '%s\n' "false"
    return 1
  fi

  local config_path="${repo_root}/.github/dnb.toml"
  if [[ ! -f "${config_path}" ]]; then
    printf '%s\n' "false"
    return 1
  fi

  # Use Python for TOML parsing (tomllib preferred; tomli fallback).
  # We print values only (no decoration). Errors go to stderr when relevant.
  local py_exit="0"
  local py_out=""

  py_out="$(
    python3 - "${config_path}" "${query}" "${opt_list_keys}" <<'PY'
import sys
from pathlib import Path

def eprint(msg: str) -> None:
  print(msg, file=sys.stderr)

def load_toml(text: str):
  # Python 3.11+: tomllib
  try:
    import tomllib  # type: ignore
    return tomllib.loads(text)
  except Exception:
    pass
  # Fallback: tomli
  try:
    import tomli  # type: ignore
    return tomli.loads(text)
  except Exception:
    raise RuntimeError("No TOML parser available. Install Python 3.11+ or 'tomli'.")

def split_path(p: str) -> list[str]:
  # Simple dot-path. No quoted segments supported.
  if not p:
    return []
  return [seg for seg in p.split(".") if seg != ""]

def get_value(doc, path: list[str]):
  cur = doc
  for seg in path:
    if not isinstance(cur, dict):
      return None
    if seg not in cur:
      return None
    cur = cur[seg]
  return cur

def is_scalar(v) -> bool:
  return isinstance(v, (str, int, float, bool))

def list_keys(doc):
  out: list[str] = []

  def walk(node, prefix: list[str]):
    if isinstance(node, dict):
      for k, v in node.items():
        walk(v, prefix + [str(k)])
      return
    if isinstance(node, list):
      # Arrays are leaves; list the path itself.
      out.append(".".join(prefix))
      return
    if is_scalar(node):
      out.append(".".join(prefix))
      return
    # Unknown types: ignore.

  walk(doc, [])
  return out

def print_value(v) -> int:
  if v is None:
    print("false")
    return 1

  if isinstance(v, dict):
    print("false")
    return 1

  if isinstance(v, list):
    for item in v:
      # For arrays, print scalars; nested arrays/tables are not supported.
      if is_scalar(item):
        # Preserve empty strings as empty lines (valid).
        print(item if isinstance(item, str) else str(item))
      else:
        print("false")
        return 1
    return 0

  if is_scalar(v):
    if isinstance(v, bool):
      print("true" if v else "false")
      return 0
    if isinstance(v, (int, float)):
      print(str(v))
      return 0
    # string (including empty)
    sys.stdout.write(v)
    if len(v) > 0:
      sys.stdout.write("\n")
    return 0

  print("false")
  return 1

def main() -> int:
  if len(sys.argv) < 4:
    print("false")
    return 1

  config_path = Path(sys.argv[1])
  query = sys.argv[2]
  opt_list = sys.argv[3].lower() == "true"

  try:
    text = config_path.read_text(encoding="utf-8")
  except Exception:
    print("false")
    return 1

  try:
    doc = load_toml(text)
  except Exception as ex:
    print("false")
    eprint(f"dnb_repo_config_get: TOML parse error: {ex}")
    return 2

  if opt_list:
    for k in list_keys(doc):
      print(k)
    return 0

  path = split_path(query)
  if not path:
    print("false")
    return 1

  v = get_value(doc, path)
  return print_value(v)

if __name__ == "__main__":
  raise SystemExit(main())
PY
  )"
  py_exit="${?}"

  if [[ "${py_exit}" -eq 0 ]]; then
    # Print exactly what python produced.
    printf '%s' "${py_out}"
    # Ensure newline if python printed a scalar without trailing newline (it does for non-empty strings).
    # For empty string, python prints nothing and exits 0, which is correct.
    return 0
  fi

  # For errors/missing, python already printed "false" plus optional stderr. Mirror stdout.
  # Ensure we print "false" if python produced nothing for some reason.
  if [[ -n "${py_out}" ]]; then
    printf '%s\n' "${py_out}"
  else
    printf '%s\n' "false"
  fi

  if [[ "${py_exit}" -eq 2 ]]; then
    return 2
  fi
  return 1
}

# Allow running as a command as well as a sourced helper.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dnb_repo_config_get "$@"
  exit "${?}"
fi
