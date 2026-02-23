#!/bin/bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${0}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TEMPLATE_FILE="${SCRIPT_DIR}/config.toml"
DEFAULT_TILE_SCRIPT="${SCRIPT_DIR}/wm-tile-window.sh"

usage() {
  cat <<EOF_USAGE
Usage:
  ${SCRIPT_NAME} [options]
  ${SCRIPT_NAME} --help

Show available tile templates in rofi and apply the selected template to the active window.

Options:
  --template-file <path>  Path to TOML template file (default: ${DEFAULT_TEMPLATE_FILE}).
  --tile-script <path>    Path to wm-tile-window.sh (default: ${DEFAULT_TILE_SCRIPT}).
  --rofi-theme <value>    Passed to rofi as: -theme <value> (optional).
  --prompt <text>         Prompt label shown by rofi (default: "Tile template").
  --verbose               Verbose debug output to stderr.
  --help                  Show this help.

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --prompt "Resize window" --rofi-theme "gruvbox-dark"
  ${SCRIPT_NAME} --template-file "${DEFAULT_TEMPLATE_FILE}" --tile-script "${DEFAULT_TILE_SCRIPT}" --verbose
EOF_USAGE
}

die() {
  local message="${1}"
  echo "ERROR: ${message}" >&2
  echo >&2
  usage >&2
  exit 1
}

logv() {
  local message="${1}"
  if [[ "${VERBOSE}" == "1" ]]; then
    echo "DEBUG: ${message}" >&2
  fi
}

need_cmd() {
  command -v "${1}" >/dev/null 2>&1
}

VERBOSE="0"
TEMPLATE_FILE="${DEFAULT_TEMPLATE_FILE}"
TILE_SCRIPT="${DEFAULT_TILE_SCRIPT}"
ROFI_THEME=""
PROMPT="Tile template"

while [[ ${#} -gt 0 ]]; do
  case "${1}" in
  --help)
    usage
    exit 0
    ;;
  --verbose)
    VERBOSE="1"
    shift
    ;;
  --template-file)
    shift
    [[ ${#} -gt 0 ]] || die "--template-file requires a value"
    TEMPLATE_FILE="${1}"
    shift
    ;;
  --tile-script)
    shift
    [[ ${#} -gt 0 ]] || die "--tile-script requires a value"
    TILE_SCRIPT="${1}"
    shift
    ;;
  --rofi-theme)
    shift
    [[ ${#} -gt 0 ]] || die "--rofi-theme requires a value"
    ROFI_THEME="${1}"
    shift
    ;;
  --prompt)
    shift
    [[ ${#} -gt 0 ]] || die "--prompt requires a value"
    PROMPT="${1}"
    shift
    ;;
  *)
    die "Unknown option: ${1}"
    ;;
  esac
done

need_cmd rofi || die "rofi is not installed. Install with: sudo apt install rofi"
need_cmd python3 || die "python3 is not installed. Install with: sudo apt install python3"

[[ -f "${TEMPLATE_FILE}" ]] || die "Template TOML file not found: ${TEMPLATE_FILE}"
[[ -f "${TILE_SCRIPT}" ]] || die "Tile script not found: ${TILE_SCRIPT}"
[[ -x "${TILE_SCRIPT}" ]] || die "Tile script is not executable: ${TILE_SCRIPT}"

logv "Template file: ${TEMPLATE_FILE}"
logv "Tile script: ${TILE_SCRIPT}"

menu="$({
  python3 - "${TEMPLATE_FILE}" <<'PY'
import sys

config_path = sys.argv[1]

try:
    import tomllib
except ModuleNotFoundError:
    print("ERROR: Python 3.11+ with tomllib is required.", file=sys.stderr)
    sys.exit(2)

try:
    with open(config_path, "rb") as handle:
        data = tomllib.load(handle)
except Exception as ex:
    print(f"ERROR: Could not parse TOML file '{config_path}': {ex}", file=sys.stderr)
    sys.exit(3)

templates = data.get("tile_template")
if not isinstance(templates, dict) or len(templates) == 0:
    print(f"ERROR: No [tile_template] entries found in '{config_path}'.", file=sys.stderr)
    sys.exit(4)

for name in sorted(templates):
    template = templates.get(name)
    if not isinstance(template, dict):
        continue

    width = template.get("width", "?")
    height = template.get("height", "?")
    h_anchor = template.get("horizontal_anchor", "?")
    h_position = template.get("horizontal_position", "?")
    v_anchor = template.get("vertical_anchor", "?")
    v_position = template.get("vertical_position", "?")

    details = f"{width}%x{height}% · h:{h_anchor}@{h_position}% · v:{v_anchor}@{v_position}%"
    print(f"{name}\t{details}")
PY
})" || die "Failed to read tile templates from ${TEMPLATE_FILE}"

[[ -n "${menu}" ]] || die "No tile templates found in ${TEMPLATE_FILE}"

logv "$(printf 'Menu entries:\n%s\n' "${menu}")"

rofi_args=(-dmenu -i -p "${PROMPT}")
if [[ -n "${ROFI_THEME}" ]]; then
  rofi_args+=(-theme "${ROFI_THEME}")
fi

selection="$(printf '%s\n' "${menu}" | rofi "${rofi_args[@]}")" || true
if [[ -z "${selection}" ]]; then
  logv "No selection (cancelled)."
  exit 0
fi

template_name="$(printf '%s\n' "${selection}" | cut -f1)"
[[ -n "${template_name}" ]] || die "Could not parse template name from selection: ${selection}"

logv "Selected template: ${template_name}"

command_args=(--template "${template_name}" --template-file "${TEMPLATE_FILE}")
if [[ "${VERBOSE}" == "1" ]]; then
  command_args+=(--verbose)
fi

"${TILE_SCRIPT}" "${command_args[@]}" || die "Failed to tile active window using template '${template_name}'"

logv "Done."
