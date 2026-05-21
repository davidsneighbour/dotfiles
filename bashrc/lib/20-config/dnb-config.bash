# shellcheck shell=bash
# shellcheck disable=SC2034

# dnb-config library
#
# Public contract:
# - Found / changed: exit 0
# - Missing file/key/value: exit 1
# - Parser, backend, or environment error: exit 2
#
# Notes:
# - TOML reads use Python 3.11+ tomllib first, preserving the existing scalar/array output contract.
# - YAML reads and all write/delete operations use dasel.
# - Selectors may be passed as simple dotted paths, for example "theme.name", or as native dasel
#   selectors, for example ".theme.name".

__dnb_config_usage_get() {
  local command_name="${1:-dnb_config_get}"

  cat <<EOF
Usage:
  ${command_name} --file PATH SELECTOR [options]
  ${command_name} --file PATH --list-keys
  ${command_name} --help

Options:
  --file PATH          Config file path.
  --selector SELECTOR  Config selector. May be used instead of positional SELECTOR.
  --list-keys          List scalar and array leaf keys. TOML only.
  --fail-on-empty      Treat empty strings and empty arrays as missing.
  --trim-values        Trim string values before printing and before empty checks.
  --print-fallback X   Print fallback on failure. Explicitly lossy.
  --help, -h           Show this help.

Exit codes:
  0  Value found
  1  Missing file, selector, value, or empty value when strict
  2  Parser, backend, or environment error
EOF
}

__dnb_config_usage_set() {
  local command_name="${1:-dnb_config_set}"

  cat <<EOF
Usage:
  ${command_name} --file PATH --selector SELECTOR --value VALUE [--type TYPE]
  ${command_name} --help

Options:
  --file PATH          Config file path.
  --selector SELECTOR  Config selector.
  --value VALUE        Value to write.
  --type TYPE          Dasel value type. Default: string.
  --help, -h           Show this help.

Common types:
  string, bool, int, float, json

Exit codes:
  0  Value written
  1  Missing file or required option
  2  Dasel/backend error
EOF
}

__dnb_config_usage_delete() {
  local command_name="${1:-dnb_config_delete}"

  cat <<EOF
Usage:
  ${command_name} --file PATH --selector SELECTOR
  ${command_name} --help

Options:
  --file PATH          Config file path.
  --selector SELECTOR  Config selector.
  --help, -h           Show this help.

Exit codes:
  0  Value deleted
  1  Missing file or required option
  2  Dasel/backend error
EOF
}

__dnb_config_require_dasel() {
  if ! command -v dasel >/dev/null 2>&1; then
    printf '%s\n' "Missing dependency: dasel" >&2
    return 2
  fi

  return 0
}

__dnb_config_file_format() {
  local file_path="${1:-}"

  case "${file_path##*.}" in
  toml)
    printf '%s\n' "toml"
    ;;
  yaml | yml)
    printf '%s\n' "yaml"
    ;;
  json)
    printf '%s\n' "json"
    ;;
  *)
    printf '%s\n' "unknown"
    ;;
  esac
}

__dnb_config_normalize_selector() {
  local selector="${1:-}"

  if [[ -z "${selector}" ]]; then
    return 1
  fi

  case "${selector}" in
  .* | \[* | *'('*')'*)
    printf '%s\n' "${selector}"
    ;;
  *)
    printf '.%s\n' "${selector}"
    ;;
  esac
}

__dnb_config_normalize_toml_query() {
  local selector="${1:-}"

  selector="${selector#.}"
  printf '%s\n' "${selector}"
}

__dnb_config_get_toml_python() {
  local file_path="${1:-}"
  local query="${2:-}"
  local opt_list_keys="${3:-false}"
  local opt_fail_on_empty="${4:-false}"
  local opt_trim_values="${5:-false}"

  python3 - "${file_path}" "${query}" "${opt_list_keys}" "${opt_fail_on_empty}" "${opt_trim_values}" <<'PY'
import sys
from pathlib import Path


def require_py311() -> None:
    if sys.version_info < (3, 11):
        raise RuntimeError("Python 3.11+ is required for TOML config reads")


def load_toml(text: str):
    require_py311()
    import tomllib

    return tomllib.loads(text)


def split_path(path: str) -> list[str]:
    return [segment for segment in path.split(".") if segment]


def get_value(document, path: list[str]):
    current = document
    for segment in path:
        if not isinstance(current, dict) or segment not in current:
            return None
        current = current[segment]
    return current


def is_scalar(value) -> bool:
    return isinstance(value, (str, int, float, bool))


def list_keys(document) -> list[str]:
    output: list[str] = []

    def walk(node, prefix: list[str]) -> None:
        if isinstance(node, dict):
            for key, value in node.items():
                walk(value, prefix + [str(key)])
            return
        if isinstance(node, list) or is_scalar(node):
            output.append(".".join(prefix))

    walk(document, [])
    return sorted(output)


def print_scalar(value, trim_values: bool) -> int:
    if isinstance(value, bool):
        print("true" if value else "false")
        return 0
    if isinstance(value, str):
        text = value.strip() if trim_values else value
        sys.stdout.write(text)
        if text:
            sys.stdout.write("\n")
        return 0
    print(value)
    return 0


def print_value(value, fail_on_empty: bool, trim_values: bool) -> int:
    if value is None or isinstance(value, dict):
        return 1

    if isinstance(value, list):
        if fail_on_empty and not value:
            return 1
        for item in value:
            if not is_scalar(item):
                return 1
            if isinstance(item, str):
                text = item.strip() if trim_values else item
                if fail_on_empty and not text:
                    return 1
                print(text)
            else:
                print("true" if item is True else "false" if item is False else item)
        return 0

    if is_scalar(value):
        if isinstance(value, str):
            text = value.strip() if trim_values else value
            if fail_on_empty and not text:
                return 1
            sys.stdout.write(text)
            if text:
                sys.stdout.write("\n")
            return 0
        return print_scalar(value, trim_values)

    return 1


def main() -> int:
    path = Path(sys.argv[1])
    query = sys.argv[2]
    opt_list = sys.argv[3] == "true"
    fail_on_empty = sys.argv[4] == "true"
    trim_values = sys.argv[5] == "true"

    try:
        document = load_toml(path.read_text(encoding="utf-8"))
    except Exception as error:
        print(error, file=sys.stderr)
        return 2

    if opt_list:
        for key in list_keys(document):
            print(key)
        return 0

    value = get_value(document, split_path(query))
    return print_value(value, fail_on_empty, trim_values)


raise SystemExit(main())
PY
}

__dnb_config_get_dasel() {
  local file_path="${1:-}"
  local selector="${2:-}"

  __dnb_config_require_dasel || return 2

  local normal_selector=""
  normal_selector="$(__dnb_config_normalize_selector "${selector}")" || return 1

  local output=""
  local error_output=""
  local exit_code="0"

  error_output="$(mktemp)" || return 2
  output="$(dasel --file "${file_path}" "${normal_selector}" 2>"${error_output}")" || exit_code="${?}"

  if [[ "${exit_code}" -ne 0 ]]; then
    output="$(dasel -f "${file_path}" "${normal_selector}" 2>"${error_output}")" || exit_code="${?}"
  fi

  if [[ "${exit_code}" -eq 0 ]]; then
    printf '%s\n' "${output}"
    rm -f "${error_output}"
    return 0
  fi

  if [[ -s "${error_output}" ]]; then
    cat "${error_output}" >&2
  fi
  rm -f "${error_output}"

  return 1
}

__dnb_config_dasel_put() {
  local file_path="${1:-}"
  local selector="${2:-}"
  local value_type="${3:-string}"
  local value="${4:-}"

  __dnb_config_require_dasel || return 2

  local normal_selector=""
  normal_selector="$(__dnb_config_normalize_selector "${selector}")" || return 1

  local error_output=""
  local exit_code="0"

  error_output="$(mktemp)" || return 2

  dasel put --file "${file_path}" --type "${value_type}" "${normal_selector}" "${value}" 2>"${error_output}" || exit_code="${?}"
  if [[ "${exit_code}" -eq 0 ]]; then
    rm -f "${error_output}"
    return 0
  fi

  exit_code="0"
  dasel put -f "${file_path}" -t "${value_type}" -v "${value}" "${normal_selector}" 2>"${error_output}" || exit_code="${?}"
  if [[ "${exit_code}" -eq 0 ]]; then
    rm -f "${error_output}"
    return 0
  fi

  exit_code="0"
  dasel put "${value_type}" --file "${file_path}" --value "${value}" "${normal_selector}" 2>"${error_output}" || exit_code="${?}"
  if [[ "${exit_code}" -eq 0 ]]; then
    rm -f "${error_output}"
    return 0
  fi

  if [[ -s "${error_output}" ]]; then
    cat "${error_output}" >&2
  fi
  rm -f "${error_output}"

  return 2
}

__dnb_config_dasel_delete() {
  local file_path="${1:-}"
  local selector="${2:-}"

  __dnb_config_require_dasel || return 2

  local normal_selector=""
  normal_selector="$(__dnb_config_normalize_selector "${selector}")" || return 1

  local error_output=""
  local exit_code="0"

  error_output="$(mktemp)" || return 2

  dasel delete --file "${file_path}" "${normal_selector}" 2>"${error_output}" || exit_code="${?}"
  if [[ "${exit_code}" -eq 0 ]]; then
    rm -f "${error_output}"
    return 0
  fi

  exit_code="0"
  dasel delete -f "${file_path}" "${normal_selector}" 2>"${error_output}" || exit_code="${?}"
  if [[ "${exit_code}" -eq 0 ]]; then
    rm -f "${error_output}"
    return 0
  fi

  if [[ -s "${error_output}" ]]; then
    cat "${error_output}" >&2
  fi
  rm -f "${error_output}"

  return 2
}

# dnb_config_get
#
# Read config values from TOML, YAML, or JSON files.
#
# Parameters:
#   --file PATH          Config file path.
#   --selector SELECTOR  Config selector. Positional selector is also supported.
#   --list-keys          List scalar and array leaf keys. TOML only.
#   --fail-on-empty      Treat empty strings and empty arrays as missing.
#   --trim-values        Trim string values before printing and checking emptiness.
#   --print-fallback X   Print explicit fallback value on failure.
#   --help, -h           Show help.
#
# Behaviour:
#   - TOML reads preserve the existing scalar/array contract through Python 3.11+ tomllib.
#   - YAML and JSON reads use dasel.
#   - Stdout is reserved for real values.
#   - Exit code 0 means found, 1 means missing, 2 means backend error.
#
# Examples:
#   dnb_config_get --file config.toml theme.name
#   dnb_config_get --file config.yaml --selector theme.name
#   dnb_config_get --file config.toml --list-keys
#   dnb_config_get --file config.toml theme.name --trim-values --fail-on-empty
dnb_config_get() {
  local file_path=""
  local selector=""

  local opt_help="false"
  local opt_list_keys="false"
  local opt_fail_on_empty="false"
  local opt_trim_values="false"
  local opt_print_fallback=""

  if [[ "${#}" -eq 0 ]]; then
    opt_help="true"
  else
    while [[ "${#}" -gt 0 ]]; do
      case "${1}" in
      --help | -h)
        opt_help="true"
        shift
        ;;
      --list-keys)
        opt_list_keys="true"
        shift
        ;;
      --file)
        shift
        [[ "${#}" -eq 0 ]] && opt_help="true" && break
        file_path="${1}"
        shift
        ;;
      --selector)
        shift
        [[ "${#}" -eq 0 ]] && opt_help="true" && break
        selector="${1}"
        shift
        ;;
      --fail-on-unset)
        shift
        ;;
      --fail-on-empty)
        opt_fail_on_empty="true"
        shift
        ;;
      --trim-values)
        opt_trim_values="true"
        shift
        ;;
      --print-fallback)
        shift
        [[ "${#}" -eq 0 ]] && opt_help="true" && break
        opt_print_fallback="${1}"
        shift
        ;;
      -*)
        opt_help="true"
        shift
        ;;
      *)
        [[ -z "${selector}" ]] && selector="${1}" || opt_help="true"
        shift
        ;;
      esac
    done
  fi

  if [[ "${opt_help}" == "true" ]]; then
    __dnb_config_usage_get "${FUNCNAME[0]}"
    return 0
  fi

  if [[ -z "${file_path}" ]]; then
    [[ -n "${opt_print_fallback}" ]] && printf '%s\n' "${opt_print_fallback}"
    return 1
  fi

  if [[ "${opt_list_keys}" == "false" && -z "${selector}" ]]; then
    [[ -n "${opt_print_fallback}" ]] && printf '%s\n' "${opt_print_fallback}"
    return 1
  fi

  if [[ ! -f "${file_path}" ]]; then
    [[ -n "${opt_print_fallback}" ]] && printf '%s\n' "${opt_print_fallback}"
    return 1
  fi

  local format=""
  format="$(__dnb_config_file_format "${file_path}")"

  local output=""
  local exit_code="0"

  if [[ "${format}" == "toml" ]]; then
    local toml_query=""
    toml_query="$(__dnb_config_normalize_toml_query "${selector}")"
    output="$(__dnb_config_get_toml_python "${file_path}" "${toml_query}" "${opt_list_keys}" "${opt_fail_on_empty}" "${opt_trim_values}")" || exit_code="${?}"
  else
    if [[ "${opt_list_keys}" == "true" ]]; then
      printf '%s\n' "--list-keys is currently supported for TOML files only" >&2
      [[ -n "${opt_print_fallback}" ]] && printf '%s\n' "${opt_print_fallback}"
      return 2
    fi

    output="$(__dnb_config_get_dasel "${file_path}" "${selector}")" || exit_code="${?}"
  fi

  if [[ "${exit_code}" -eq 0 ]]; then
    printf '%s' "${output}"
    [[ -n "${output}" ]] && printf '\n'
    return 0
  fi

  [[ -n "${opt_print_fallback}" ]] && printf '%s\n' "${opt_print_fallback}"
  [[ "${exit_code}" -eq 2 ]] && return 2
  return 1
}

# dnb_config_set
#
# Set a value in a TOML, YAML, JSON, or other dasel-supported config file.
#
# Parameters:
#   --file PATH          Config file path.
#   --selector SELECTOR  Config selector.
#   --value VALUE        Value to write.
#   --type TYPE          Dasel value type. Default: string.
#   --help, -h           Show help.
#
# Behaviour:
#   - Requires dasel.
#   - Writes to the file via dasel.
#   - Returns 0 on success, 1 for missing input, 2 for backend errors.
#
# Examples:
#   dnb_config_set --file config.toml --selector theme.name --type string --value dracula
#   dnb_config_set --file config.yaml --selector polybar.enabled --type bool --value true
dnb_config_set() {
  local file_path=""
  local selector=""
  local value=""
  local value_type="string"
  local value_seen="false"

  if [[ "${#}" -eq 0 ]]; then
    __dnb_config_usage_set "${FUNCNAME[0]}"
    return 0
  fi

  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
    --help | -h)
      __dnb_config_usage_set "${FUNCNAME[0]}"
      return 0
      ;;
    --file)
      shift
      [[ "${#}" -eq 0 ]] && __dnb_config_usage_set "${FUNCNAME[0]}" && return 1
      file_path="${1}"
      shift
      ;;
    --selector)
      shift
      [[ "${#}" -eq 0 ]] && __dnb_config_usage_set "${FUNCNAME[0]}" && return 1
      selector="${1}"
      shift
      ;;
    --value)
      shift
      [[ "${#}" -eq 0 ]] && __dnb_config_usage_set "${FUNCNAME[0]}" && return 1
      value="${1}"
      value_seen="true"
      shift
      ;;
    --type)
      shift
      [[ "${#}" -eq 0 ]] && __dnb_config_usage_set "${FUNCNAME[0]}" && return 1
      value_type="${1}"
      shift
      ;;
    *)
      printf '%s\n' "Unknown option: ${1}" >&2
      __dnb_config_usage_set "${FUNCNAME[0]}" >&2
      return 1
      ;;
    esac
  done

  if [[ -z "${file_path}" || -z "${selector}" || "${value_seen}" != "true" ]]; then
    __dnb_config_usage_set "${FUNCNAME[0]}" >&2
    return 1
  fi

  if [[ ! -f "${file_path}" ]]; then
    printf '%s\n' "Config file not found: ${file_path}" >&2
    return 1
  fi

  __dnb_config_dasel_put "${file_path}" "${selector}" "${value_type}" "${value}"
}

# dnb_config_delete
#
# Delete a value from a TOML, YAML, JSON, or other dasel-supported config file.
#
# Parameters:
#   --file PATH          Config file path.
#   --selector SELECTOR  Config selector.
#   --help, -h           Show help.
#
# Behaviour:
#   - Requires dasel.
#   - Returns 0 on success, 1 for missing input, 2 for backend errors.
#
# Example:
#   dnb_config_delete --file config.toml --selector deprecated.option
dnb_config_delete() {
  local file_path=""
  local selector=""

  if [[ "${#}" -eq 0 ]]; then
    __dnb_config_usage_delete "${FUNCNAME[0]}"
    return 0
  fi

  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
    --help | -h)
      __dnb_config_usage_delete "${FUNCNAME[0]}"
      return 0
      ;;
    --file)
      shift
      [[ "${#}" -eq 0 ]] && __dnb_config_usage_delete "${FUNCNAME[0]}" && return 1
      file_path="${1}"
      shift
      ;;
    --selector)
      shift
      [[ "${#}" -eq 0 ]] && __dnb_config_usage_delete "${FUNCNAME[0]}" && return 1
      selector="${1}"
      shift
      ;;
    *)
      printf '%s\n' "Unknown option: ${1}" >&2
      __dnb_config_usage_delete "${FUNCNAME[0]}" >&2
      return 1
      ;;
    esac
  done

  if [[ -z "${file_path}" || -z "${selector}" ]]; then
    __dnb_config_usage_delete "${FUNCNAME[0]}" >&2
    return 1
  fi

  if [[ ! -f "${file_path}" ]]; then
    printf '%s\n' "Config file not found: ${file_path}" >&2
    return 1
  fi

  __dnb_config_dasel_delete "${file_path}" "${selector}"
}

# dnb_config_has
#
# Check whether a selector exists without printing the value.
#
# Parameters:
#   Same as dnb_config_get, except output is discarded.
#
# Example:
#   if dnb_config_has --file config.toml theme.name; then
#     printf '%s\n' "theme.name exists"
#   fi
dnb_config_has() {
  dnb_config_get "$@" >/dev/null
}

# dnb_config_list_keys
#
# List supported scalar and array leaf keys. TOML only.
#
# Parameters:
#   --file PATH  Config file path.
#
# Example:
#   dnb_config_list_keys --file config.toml
dnb_config_list_keys() {
  dnb_config_get --list-keys "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dnb_config_get "$@"
  exit "${?}"
fi
