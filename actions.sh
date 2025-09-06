#!/bin/bash
# Pick and run actions from a TOML file via gum
# Dependencies: bash, python3 (tomllib or tomli), gum
# shellcheck disable=SC2016

# uses:
# - https://github.com/charmbracelet/gum
# - https://github.com/muesli/termenv#template-helpers
# - https://api.github.com/emojis

set -euo pipefail

# ----------------------------
# Globals & defaults
# ----------------------------
SCRIPT_NAME="$(basename "$0")"
CONFIG_FILE="./configs/actions/actions.toml"   # default if no --config is provided
VERBOSE="false"
DRY_RUN="false"
LOG_DIR="${HOME}/.logs/actions"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
LOG_FILE="${LOG_DIR}/${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

# Resolve dotfiles root dynamically relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "${SCRIPT_DIR}" && pwd)"
export DOTFILES

# ----------------------------
# Logging helpers
# ----------------------------
log() {
  local level="${1:-INFO}"; shift || true
  local msg="${*:-}"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s [%s] %s\n' "${ts}" "${level}" "${msg}" | tee -a "${LOG_FILE}" >/dev/null
}

vlog() {
  if [[ "${VERBOSE}" == "true" ]]; then
    log "DEBUG" "$*"
  fi
}

err() {
  log "ERROR" "$*" >&2
}

# ----------------------------
# Usage
# ----------------------------
print_help() {
  cat <<EOF
${SCRIPT_NAME} - Select and execute actions from a TOML config using gum

Usage:
  ${SCRIPT_NAME} [--config <path>] [--verbose] [--dry-run]
  ${SCRIPT_NAME} --help

Options:
  --config <path>   Path to TOML configuration file (default: ./actions.toml).
  --verbose         Print debug information.
  --dry-run         Do not execute actions, only print what would run.
  --help            Show this help.

Behavior:
  * Loads .env files (current dir first, then HOME) for variable expansion.
  * Presents Scope -> Activity selection (via gum).
  * Scopes and activities both support labels in TOML.
  * Prints the exact command with expanded variables and highlights values.
  * Confirms before execution.
  * After completion, asks More or Exit and loops until exit.

Logs:
  * Writes to ${LOG_FILE}
EOF
}

# ----------------------------
# Arg parsing
# ----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      shift
      CONFIG_FILE="${1:-}"
      if [[ -z "${CONFIG_FILE}" ]]; then
        err "Missing value for --config"
        exit 1
      fi
      ;;
    --verbose)
      VERBOSE="true"
      ;;
    --dry-run)
      DRY_RUN="true"
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      print_help
      exit 1
      ;;
  esac
  shift
done

# ----------------------------
# Preconditions
# ----------------------------
if ! command -v gum >/dev/null 2>&1; then
  err "gum not found. Install from https://github.com/charmbracelet/gum"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  err "python3 not found. Please install Python 3.11+."
  exit 1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  err "Config file not found: ${CONFIG_FILE}"
  exit 1
fi

# ----------------------------
# Load environment (.env): PWD first, then HOME
# ----------------------------
load_env_file() {
  local env_path="$1"
  if [[ -f "${env_path}" ]]; then
    vlog "Loading env file: ${env_path}"
    while IFS='=' read -r key value; do
      [[ -z "${key}" ]] && continue
      [[ "${key}" =~ ^[[:space:]]*# ]] && continue
      value="${value%\"}"; value="${value#\"}"
      value="${value%\'}"; value="${value#\'}"
      export "${key}"="${value}"
    done < <(grep -v '^[[:space:]]*#' "${env_path}" | grep '=' || true)
  fi
}
load_env_file "${PWD}/.env"
load_env_file "${HOME}/.env"

# ----------------------------
# Python TOML accessors
# ----------------------------
py_toml() {
  # Modes:
  #   list_scopes
  #   get_scope_label <scope>
  #   list_activities <scope>
  #   get_activity_label <scope> <activity>
  #   get_activity_cmd   <scope> <activity>
  python3 - "$@" <<'PYCODE'
import sys, os
try:
    import tomllib
except Exception:
    try:
        import tomli as tomllib
    except Exception:
        print("ERROR: Python tomllib/tomli not available.", file=sys.stderr)
        sys.exit(42)

config_path = os.environ.get("CONFIG_FILE")
if not config_path:
    print("ERROR: CONFIG_FILE not set in environment.", file=sys.stderr)
    sys.exit(43)

try:
    with open(config_path, "rb") as f:
        data = tomllib.load(f)
except FileNotFoundError:
    print(f"ERROR: Config not found: {config_path}", file=sys.stderr)
    sys.exit(44)

def list_scopes():
    for name in data.get("scopes", {}).keys():
        print(name)

def get_scope_label(scope):
    print(data.get("scopes", {}).get(scope, {}).get("label", ""))

def list_activities(scope):
    for a in data.get("scopes", {}).get(scope, {}).get("activities", {}).keys():
        print(a)

def get_activity_label(scope, activity):
    print(data.get("scopes", {}).get(scope, {}).get("activities", {}).get(activity, {}).get("label", ""))

def get_activity_cmd(scope, activity):
    print(data.get("scopes", {}).get(scope, {}).get("activities", {}).get(activity, {}).get("cmd", ""))

mode = sys.argv[1] if len(sys.argv) > 1 else ""
if mode == "list_scopes":
    list_scopes()
elif mode == "get_scope_label":
    if len(sys.argv) < 3: sys.exit(2)
    get_scope_label(sys.argv[2])
elif mode == "list_activities":
    if len(sys.argv) < 3: sys.exit(2)
    list_activities(sys.argv[2])
elif mode == "get_activity_label":
    if len(sys.argv) < 4: sys.exit(2)
    get_activity_label(sys.argv[2], sys.argv[3])
elif mode == "get_activity_cmd":
    if len(sys.argv) < 4: sys.exit(2)
    get_activity_cmd(sys.argv[2], sys.argv[3])
else:
    print(f"ERROR: Unknown mode '{mode}'", file=sys.stderr); sys.exit(2)
PYCODE
}

export CONFIG_FILE

# ----------------------------
# Selection UI
# ----------------------------
choose_scope() {
  local scopes joined label
  if ! scopes="$(py_toml list_scopes)"; then
    err "Failed to read scopes from config."
    exit 1
  fi
  if [[ -z "${scopes}" ]]; then
    err "No scopes defined in config."
    exit 1
  fi

  joined=""
  while IFS= read -r s; do
    label="$(py_toml get_scope_label "${s}")"
    if [[ -z "${joined}" ]]; then
      joined="${s}: ${label}"
    else
      joined="${joined}"$'\n'"${s}: ${label}"
    fi
  done <<< "${scopes}"

  printf '%s\n' "${joined}" | gum choose --header="Select a scope"
}

choose_activity() {
  local scope="$1"
  local acts joined label
  if ! acts="$(py_toml list_activities "${scope}")"; then
    err "Failed to read activities for scope '${scope}'."
    exit 1
  fi
  if [[ -z "${acts}" ]]; then
    err "No activities in scope '${scope}'."
    exit 1
  fi

  joined=""
  while IFS= read -r a; do
    label="$(py_toml get_activity_label "${scope}" "${a}")"
    if [[ -z "${joined}" ]]; then
      joined="${a}: ${label}"
    else
      joined="${joined}"$'\n'"${a}: ${label}"
    fi
  done <<< "${acts}"

  printf '%s\n' "${joined}" | gum choose --header="Select an activity"
}

extract_left_of_colon() {
  local line="$1"
  printf '%s' "${line%%:*}"
}

# ----------------------------
# Highlight helpers
# ----------------------------
# Find variable names used in the command template and colorize their expanded values.
colorize_expanded() {
  local template="$1"
  local expanded="$2"
  local colored="$expanded"

  # ANSI colors
  local CVAL=$'\033[38;5;45m'  # cyan
  local CRESET=$'\033[0m'

  # Collect variable names from the template: $VAR and ${VAR}
  # shellcheck disable=SC2001
  local vars
  vars="$(printf '%s' "${template}" \
    | grep -oE '\$[A-Za-z_][A-Za-z0-9_]*|\$\{[A-Za-z_][A-Za-z0-9_]*\}' \
    | sed -E 's/^\$//; s/^\{//; s/\}$//' \
    | sort -u)"

  if [[ -z "${vars}" ]]; then
    printf '%s' "${expanded}"
    return 0
  fi

  # Replace each value occurrence with colored value
  local name val safe_val
  while IFS= read -r name; do
    # Skip empty names just in case
    [[ -z "${name}" ]] && continue
    # Resolve value safely
    # Use 'printf %s' to avoid interpreting escapes
    # shellcheck disable=SC2086
    val="$(eval "printf '%s' \"\${${name}:-}\"")"
    [[ -z "${val}" ]] && continue

    # Replace all occurrences in the expanded string
    # Use bash replacement to avoid sed escaping issues
    safe_val="${CVAL}${val}${CRESET}"
    colored="${colored//${val}/${safe_val}}"
  done <<< "${vars}"

  printf '%s' "${colored}"
}

# ----------------------------
# Execution
# ----------------------------
run_activity() {
  local scope="$1"
  local activity="$2"
  local cmd expanded_cmd colored_cmd
  cmd="$(py_toml get_activity_cmd "${scope}" "${activity}")"

  if [[ -z "${cmd}" ]]; then
    err "No command defined for ${scope}/${activity}"
    return 1
  fi

  log "INFO" "Selected: ${scope}/${activity}"
  log "INFO" "Command template: ${cmd}"

  # Expand variables for preview
  expanded_cmd="$(eval "echo \"$cmd\"")"
  colored_cmd="$(colorize_expanded "${cmd}" "${expanded_cmd}")"

  # Show both template and expanded preview with emojis
  gum style --border double --padding "1 2" --margin "1 0" \
    "📜 Template:" "${cmd}" "" "🔍 Expanded:" "${colored_cmd}"

  # Confirm
  if gum confirm "Execute this command?" --affirmative="Run" --negative="Cancel"; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log "INFO" "[DRY-RUN] Skipping execution."
    else
      if bash -c "${cmd}"; then
        log "INFO" "✅ Success: ${scope}/${activity}"
      else
        err "❌ Command failed for ${scope}/${activity}"
        return 1
      fi
    fi
  else
    log "INFO" "🚫 Execution cancelled."
  fi
}

# ----------------------------
# Main loop
# ----------------------------
main_loop() {
  log "INFO" "Starting ${SCRIPT_NAME} with config: ${CONFIG_FILE}"
  while true; do
    local scope_line scope activity_line activity
    scope_line="$(choose_scope)"
    scope="$(extract_left_of_colon "${scope_line}")"

    activity_line="$(choose_activity "${scope}")"
    activity="$(extract_left_of_colon "${activity_line}")"

    run_activity "${scope}" "${activity}"

    if gum confirm "Done?" --affirmative="Exit" --negative="More"; then
      log "INFO" "Exiting."
      break
    else
      continue
    fi
  done
}

main_loop
