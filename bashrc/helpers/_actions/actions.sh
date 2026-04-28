#!/bin/bash
# Unified actions helper for interactive actions, autostart management, and Dotbot setup runs.
# shellcheck disable=SC2016

set -euo pipefail

SCRIPT_NAME="$(basename "${0}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

DEFAULT_ACTIONS_CONFIG="${DOTFILES_ROOT}/configs/actions/actions.toml"
DEFAULT_AUTOSTART_DIR="${DOTFILES_ROOT}/configs/system/autostart"
DEFAULT_DOTBOT_CONFIGS_DIR="${DOTFILES_ROOT}/configs/dotbot"
DOTBOT_HELPER="${DOTFILES_ROOT}/bashrc/helpers/dotbot"

VERBOSE="false"
DRY_RUN="false"

source_core_libs() {
  local base_path="${BASHRC_PATH:-${DOTFILES_ROOT}/bashrc}"
  local file=""

  for file in "${base_path}"/lib/00-core/*.bash; do
    [[ -f "${file}" && -r "${file}" ]] || continue
    # shellcheck disable=SC1090
    source "${file}"
  done
}

init_logging() {
  local log_dir="${HOME}/.logs/actions"
  __LOGFILE="${log_dir}/actions-$(date '+%Y%m%d-%H%M%S').log"
  export __LOGFILE
}

log_msg() {
  local level="${1:-info}"
  shift || true
  local msg="${*:-}"
  level="${level,,}"
  dnb_log "${level}" "${msg}"
}

log_debug() {
  if [[ "${VERBOSE}" == "true" ]]; then
    log_msg "info" "$*"
  fi
}

log_error() {
  dnb_error "$*"
}

print_help() {
  cat <<EOF_HELP
${SCRIPT_NAME} - Unified helper for dotfiles actions.

Usage:
  ${SCRIPT_NAME} [global-options] [command] [command-options]

Global options:
  --verbose               Enable debug output.
  --dry-run               Print planned changes without executing them.
  --help                  Show this help.

Commands:
  menu                    Run the TOML-driven action picker (default command).
  autostart-enable        Enable one or more autostart entries for a host.
  autostart-disable       Disable one or more autostart entries for a host.
  dotbot-list             List available Dotbot setup profiles from configs/dotbot.
  dotbot-run              Run Dotbot using a setup profile from configs/dotbot.

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --verbose menu --config "${DEFAULT_ACTIONS_CONFIG}"
  ${SCRIPT_NAME} autostart-enable --host "$(hostname)"
  ${SCRIPT_NAME} autostart-disable --host "$(hostname)"
  ${SCRIPT_NAME} dotbot-list
  ${SCRIPT_NAME} dotbot-run --profile protected

Logs:
  ${__LOGFILE:-<not-initialized>}
EOF_HELP
}

require_cmd() {
  local cmd="${1}"
  if ! dnb_check_requirements "${cmd}" >/dev/null 2>&1; then
    log_error "Required command '${cmd}' was not found in PATH."
    exit 1
  fi
}

get_desktop_entry_value() {
  local file_path="${1}"
  local exact_key="${2}"
  local localized_prefix="${3}"
  local line=""
  local key=""
  local value=""
  local in_desktop_entry="false"

  while IFS= read -r line; do
    if [[ "${line}" == "[Desktop Entry]" ]]; then
      in_desktop_entry="true"
      continue
    fi

    if [[ "${in_desktop_entry}" != "true" ]]; then
      continue
    fi

    if [[ "${line}" =~ ^\[.*\]$ ]]; then
      break
    fi

    if [[ "${line}" != *=* ]]; then
      continue
    fi

    key="${line%%=*}"
    value="${line#*=}"

    if [[ "${key}" == "${exact_key}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi

    if [[ "${key}" =~ ^${localized_prefix}\[[^]]+\]$ ]]; then
      printf '%s\n' "${value}"
      return 0
    fi
  done < "${file_path}"

  return 1
}

build_select_line() {
  local index="${1}"
  local title="${2}"
  local description="${3}"
  local title_color=$'\033[38;2;248;248;242m'
  local description_color=$'\033[38;2;112;140;169m'
  local color_reset=$'\033[0m'

  if [[ -n "${description}" ]]; then
    printf '%s\n' "${index}) ${title_color}${title}${color_reset} ${description_color}${description}${color_reset}"
    return
  fi

  printf '%s\n' "${index}) ${title_color}${title}${color_reset}"
}

parse_desktop_selections() {
  local selected_out="${1}"
  local -n out_array_ref="${2}"
  local -n by_index_ref="${3}"
  local line=""
  local selection_id=""

  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    selection_id="${line%%)*}"
    if [[ "${selection_id}" =~ ^[0-9]+$ ]] && [[ -n "${by_index_ref[${selection_id}]:-}" ]]; then
      out_array_ref+=("${by_index_ref[${selection_id}]}")
    fi
  done <<< "${selected_out}"
}

menu_py_toml() {
  python3 - "$@" <<'PYCODE'
import os
import sys

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
    with open(config_path, "rb") as handle:
        data = tomllib.load(handle)
except FileNotFoundError:
    print(f"ERROR: Config not found: {config_path}", file=sys.stderr)
    sys.exit(44)

mode = sys.argv[1] if len(sys.argv) > 1 else ""

if mode == "list_scopes":
    for scope_name in data.get("scopes", {}).keys():
        print(scope_name)
elif mode == "get_scope_label":
    if len(sys.argv) < 3:
        sys.exit(2)
    print(data.get("scopes", {}).get(sys.argv[2], {}).get("label", ""))
elif mode == "list_activities":
    if len(sys.argv) < 3:
        sys.exit(2)
    for activity_name in data.get("scopes", {}).get(sys.argv[2], {}).get("activities", {}).keys():
        print(activity_name)
elif mode == "get_activity_label":
    if len(sys.argv) < 4:
        sys.exit(2)
    print(data.get("scopes", {}).get(sys.argv[2], {}).get("activities", {}).get(sys.argv[3], {}).get("label", ""))
elif mode == "get_activity_cmd":
    if len(sys.argv) < 4:
        sys.exit(2)
    print(data.get("scopes", {}).get(sys.argv[2], {}).get("activities", {}).get(sys.argv[3], {}).get("cmd", ""))
else:
    print(f"ERROR: Unknown mode '{mode}'", file=sys.stderr)
    sys.exit(2)
PYCODE
}

colorize_expanded() {
  local template="${1}"
  local expanded="${2}"
  local colored="${expanded}"
  local cval=$'\033[38;5;45m'
  local creset=$'\033[0m'

  local vars
  vars="$(printf '%s' "${template}" | grep -oE '\$[A-Za-z_][A-Za-z0-9_]*|\$\{[A-Za-z_][A-Za-z0-9_]*\}' | sed -E 's/^\$//; s/^\{//; s/\}$//' | sort -u || true)"

  [[ -z "${vars}" ]] && { printf '%s' "${expanded}"; return 0; }

  local name=""
  local val=""
  local safe_val=""
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    val="$(eval "printf '%s' \"\${${name}:-}\"")"
    [[ -z "${val}" ]] && continue
    safe_val="${cval}${val}${creset}"
    colored="${colored//${val}/${safe_val}}"
  done <<< "${vars}"

  printf '%s' "${colored}"
}

menu_choose_scope() {
  local scopes=""
  local scope=""
  local label=""
  local joined=""

  scopes="$(menu_py_toml list_scopes)"
  if [[ -z "${scopes}" ]]; then
    log_error "No scopes defined in actions configuration."
    return 1
  fi

  while IFS= read -r scope; do
    label="$(menu_py_toml get_scope_label "${scope}")"
    if [[ -z "${joined}" ]]; then
      joined="${scope}: ${label}"
    else
      joined+=$'\n'"${scope}: ${label}"
    fi
  done <<< "${scopes}"

  printf '%s\n' "${joined}" | gum choose --header "Select a scope"
}

menu_choose_activity() {
  local scope="${1}"
  local activities=""
  local activity=""
  local label=""
  local joined=""

  activities="$(menu_py_toml list_activities "${scope}")"
  if [[ -z "${activities}" ]]; then
    log_error "No activities defined for scope '${scope}'."
    return 1
  fi

  while IFS= read -r activity; do
    label="$(menu_py_toml get_activity_label "${scope}" "${activity}")"
    if [[ -z "${joined}" ]]; then
      joined="${activity}: ${label}"
    else
      joined+=$'\n'"${activity}: ${label}"
    fi
  done <<< "${activities}"

  printf '%s\n' "${joined}" | gum choose --header "Select an activity"
}

menu_extract_id() {
  local line="${1}"
  printf '%s' "${line%%:*}"
}

menu_run_activity() {
  local scope="${1}"
  local activity="${2}"
  local cmd=""
  local expanded_cmd=""
  local colored_cmd=""

  cmd="$(menu_py_toml get_activity_cmd "${scope}" "${activity}")"
  if [[ -z "${cmd}" ]]; then
    log_error "No command configured for ${scope}/${activity}."
    return 1
  fi

  log_msg "INFO" "Selected action ${scope}/${activity}."
  expanded_cmd="$(eval "printf '%s' \"${cmd}\"")"
  colored_cmd="$(colorize_expanded "${cmd}" "${expanded_cmd}")"

  gum style --border double --padding "1 2" --margin "1 0" "📜 Template:" "${cmd}" "" "🔍 Expanded:" "${colored_cmd}"

  if gum confirm "Execute this command?" --affirmative="Run" --negative="Cancel"; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_msg "INFO" "[DRY-RUN] Skipped execution for ${scope}/${activity}."
    else
      if bash -c "${cmd}"; then
        log_msg "INFO" "Action completed successfully: ${scope}/${activity}."
      else
        log_error "Action failed: ${scope}/${activity}."
        return 1
      fi
    fi
  else
    log_msg "INFO" "Action execution cancelled by user for ${scope}/${activity}."
  fi
}

handle_menu() {
  local config_file="${DEFAULT_ACTIONS_CONFIG}"

  while (($#)); do
    case "${1}" in
      --config)
        config_file="${2:-}"
        if [[ -z "${config_file}" ]]; then
          log_error "--config requires a value."
          return 1
        fi
        shift 2
        ;;
      --help)
        cat <<EOF_HELP
Usage: ${SCRIPT_NAME} menu [--config FILE]

Run the interactive menu backed by a TOML file.

Options:
  --config FILE   Path to actions TOML file (default: ${DEFAULT_ACTIONS_CONFIG})
  --help          Show this help
EOF_HELP
        return 0
        ;;
      *)
        log_error "Unknown option for menu: ${1}"
        return 1
        ;;
    esac
  done

  require_cmd gum
  require_cmd python3

  if [[ ! -f "${config_file}" ]]; then
    log_error "Actions config file was not found: ${config_file}."
    return 1
  fi

  export CONFIG_FILE="${config_file}"
  export DOTFILES="${DOTFILES_ROOT}"

  while true; do
    local scope_line=""
    local activity_line=""
    local scope=""
    local activity=""

    scope_line="$(menu_choose_scope)"
    scope="$(menu_extract_id "${scope_line}")"

    activity_line="$(menu_choose_activity "${scope}")"
    activity="$(menu_extract_id "${activity_line}")"

    menu_run_activity "${scope}" "${activity}"

    if gum confirm "Done?" --affirmative="Exit" --negative="More"; then
      break
    fi
  done
}

handle_autostart_enable() {
  local dir_autostarts="${DEFAULT_AUTOSTART_DIR}"
  local dir_available="${DEFAULT_AUTOSTART_DIR}/available"
  local host_name="${HOSTNAME:-unknown-host}"
  local prompt="Select an item:"

  while (($#)); do
    case "${1}" in
      --dir)
        dir_available="${2:-}"
        if [[ -z "${dir_available}" ]]; then
          log_error "--dir requires a value."
          return 1
        fi
        shift 2
        ;;
      --dir-autostarts)
        dir_autostarts="${2:-}"
        if [[ -z "${dir_autostarts}" ]]; then
          log_error "--dir-autostarts requires a value."
          return 1
        fi
        shift 2
        ;;
      --host)
        host_name="${2:-}"
        if [[ -z "${host_name}" ]]; then
          log_error "--host requires a value."
          return 1
        fi
        shift 2
        ;;
      --prompt)
        prompt="${2:-}"
        if [[ -z "${prompt}" ]]; then
          log_error "--prompt requires a value."
          return 1
        fi
        shift 2
        ;;
      --help)
        cat <<EOF_HELP
Usage: ${SCRIPT_NAME} autostart-enable [--dir DIR] [--dir-autostarts DIR] [--host HOST] [--prompt TEXT]

Enable one or more autostart desktop entries by creating symlinks under:
  <dir-autostarts>/<host>/

Options:
  --dir DIR              Directory with available desktop entries.
  --dir-autostarts DIR   Base autostart directory.
  --host HOST            Host directory name.
  --prompt TEXT          Prompt text for gum.
  --help                 Show this help.
EOF_HELP
        return 0
        ;;
      *)
        log_error "Unknown option for autostart-enable: ${1}"
        return 1
        ;;
    esac
  done

  require_cmd gum

  if [[ "${dir_available}" == "${DEFAULT_AUTOSTART_DIR}/available" ]]; then
    dir_available="${dir_autostarts%/}/available"
  fi

  if [[ ! -d "${dir_available}" ]]; then
    log_error "Autostart source directory was not found: ${dir_available}."
    return 1
  fi

  shopt -s nullglob
  local entries=("${dir_available%/}"/*)
  shopt -u nullglob

  if (( ${#entries[@]} == 0 )); then
    log_error "No entries available in ${dir_available}."
    return 1
  fi

  # shellcheck disable=SC2034 # referenced through nameref in parse_desktop_selections
  local -A selection_by_index=()
  local selection_lines=()
  local index=1
  local p=""
  local base_name=""
  local title=""
  local description=""
  local parsed_title=""
  local parsed_description=""

  for p in "${entries[@]}"; do
    base_name="$(basename -- "${p}")"
    title="${base_name}"
    description=""

    if [[ -f "${p}" ]]; then
      parsed_title=""
      parsed_description=""
      if parsed_title="$(get_desktop_entry_value "${p}" "Name" "Name")"; then
        title="${parsed_title}"
      fi
      if parsed_description="$(get_desktop_entry_value "${p}" "Comment" "Comment")"; then
        description="${parsed_description}"
      fi
    fi

    # shellcheck disable=SC2034 # referenced through nameref in parse_desktop_selections
    selection_by_index["${index}"]="${base_name}"
    selection_lines+=("$(build_select_line "${index}" "${title}" "${description}")")
    ((index++))
  done

  local selected_out=""
  if ! selected_out="$(printf '%b\n' "${selection_lines[@]}" | gum filter --placeholder "${prompt}" --no-limit)"; then
    log_error "No selection made."
    return 1
  fi

  local selections=()
  parse_desktop_selections "${selected_out}" selections selection_by_index

  local destination_dir="${dir_autostarts%/}/${host_name}"
  mkdir -p -- "${destination_dir}"

  local sel=""
  local src=""
  local dst=""
  local action=""

  for sel in "${selections[@]}"; do
    src="${dir_available%/}/${sel}"
    dst="${destination_dir}/${sel}"

    if [[ ! -e "${src}" ]]; then
      log_error "Source entry not found, skipping: ${src}."
      continue
    fi

    if [[ -L "${dst}" || -e "${dst}" ]]; then
      if [[ -L "${dst}" ]] && [[ "$(readlink -- "${dst}")" == "${src}" ]]; then
        log_msg "INFO" "Already linked: ${dst} -> ${src}"
        continue
      fi

      action="$(printf '%s\n' "replace" "skip" | gum choose --header "File exists: ${sel}. What now?")"
      if [[ "${action}" == "replace" ]]; then
        if [[ "${DRY_RUN}" == "true" ]]; then
          log_msg "INFO" "[DRY-RUN] Would replace ${dst} -> ${src}."
        else
          rm -f -- "${dst}"
          ln -s -- "${src}" "${dst}"
          log_msg "INFO" "Replaced ${dst} -> ${src}."
        fi
      else
        log_msg "INFO" "Skipped ${dst}."
      fi
    else
      if [[ "${DRY_RUN}" == "true" ]]; then
        log_msg "INFO" "[DRY-RUN] Would link ${dst} -> ${src}."
      else
        ln -s -- "${src}" "${dst}"
        printf ':heavy_check_mark: Linked: %s -> %s\n' "${dst}" "${src}" | gum format -t emoji
      fi
    fi
  done
}

handle_autostart_disable() {
  local dir_autostarts="${DEFAULT_AUTOSTART_DIR}"
  local host_name="${HOSTNAME:-unknown-host}"
  local prompt="Select symlink(s) to remove:"

  while (($#)); do
    case "${1}" in
      --host)
        host_name="${2:-}"
        if [[ -z "${host_name}" ]]; then
          log_error "--host requires a value."
          return 1
        fi
        shift 2
        ;;
      --dir-autostarts)
        dir_autostarts="${2:-}"
        if [[ -z "${dir_autostarts}" ]]; then
          log_error "--dir-autostarts requires a value."
          return 1
        fi
        shift 2
        ;;
      --prompt)
        prompt="${2:-}"
        if [[ -z "${prompt}" ]]; then
          log_error "--prompt requires a value."
          return 1
        fi
        shift 2
        ;;
      --help)
        cat <<EOF_HELP
Usage: ${SCRIPT_NAME} autostart-disable [--host HOST] [--dir-autostarts DIR] [--prompt TEXT]

Disable one or more autostart desktop entries by removing symlinks under:
  <dir-autostarts>/<host>/

Options:
  --host HOST            Host directory name.
  --dir-autostarts DIR   Base autostart directory.
  --prompt TEXT          Prompt text for gum.
  --help                 Show this help.
EOF_HELP
        return 0
        ;;
      *)
        log_error "Unknown option for autostart-disable: ${1}"
        return 1
        ;;
    esac
  done

  require_cmd gum

  local destination_dir="${dir_autostarts%/}/${host_name}"
  if [[ ! -d "${destination_dir}" ]]; then
    log_error "Host autostart directory was not found: ${destination_dir}."
    return 1
  fi

  shopt -s nullglob
  local entries=("${destination_dir}"/*)
  shopt -u nullglob

  local symlinks=()
  local p=""
  for p in "${entries[@]}"; do
    if [[ -L "${p}" ]]; then
      symlinks+=("${p}")
    fi
  done

  if (( ${#symlinks[@]} == 0 )); then
    log_error "No symlinks found in ${destination_dir}."
    return 1
  fi

  # shellcheck disable=SC2034 # referenced through nameref in parse_desktop_selections
  local -A selection_by_index=()
  local selection_lines=()
  local index=1
  local base_name=""
  local title=""
  local description=""
  local source_entry=""
  local parsed_title=""
  local parsed_description=""

  for p in "${symlinks[@]}"; do
    base_name="$(basename -- "${p}")"
    title="${base_name}"
    description=""
    source_entry="${dir_autostarts%/}/available/${base_name}"

    if [[ -f "${source_entry}" ]]; then
      parsed_title=""
      parsed_description=""
      if parsed_title="$(get_desktop_entry_value "${source_entry}" "Name" "Name")"; then
        title="${parsed_title}"
      fi
      if parsed_description="$(get_desktop_entry_value "${source_entry}" "Comment" "Comment")"; then
        description="${parsed_description}"
      fi
    fi

    # shellcheck disable=SC2034 # referenced through nameref in parse_desktop_selections
    selection_by_index["${index}"]="${base_name}"
    selection_lines+=("$(build_select_line "${index}" "${title}" "${description}")")
    ((index++))
  done

  local selected_out=""
  if ! selected_out="$(printf '%b\n' "${selection_lines[@]}" | gum filter --placeholder "${prompt}" --no-limit)"; then
    log_error "No selection made."
    return 1
  fi

  local selections=()
  parse_desktop_selections "${selected_out}" selections selection_by_index

  local sel=""
  local target_path=""
  for sel in "${selections[@]}"; do
    target_path="${destination_dir}/${sel}"
    if [[ -L "${target_path}" ]]; then
      if [[ "${DRY_RUN}" == "true" ]]; then
        log_msg "INFO" "[DRY-RUN] Would remove ${target_path}."
      else
        rm -f -- "${target_path}"
        log_msg "INFO" "Removed symlink: ${target_path}."
      fi
    else
      log_error "Skipped non-symlink: ${target_path}."
    fi
  done
}

extract_dotbot_description() {
  local config_file="${1}"
  local description_line=""
  description_line="$(grep -m 1 -E '^- description:[[:space:]]*' "${config_file}" || true)"
  description_line="${description_line#- description:}"
  description_line="${description_line#\"}"
  description_line="${description_line%\"}"
  description_line="${description_line#\'}"
  description_line="${description_line%\'}"
  description_line="$(printf '%s' "${description_line}" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')"

  if [[ -z "${description_line}" ]]; then
    printf '%s\n' "(no description)"
    return 0
  fi

  printf '%s\n' "${description_line}"
}

list_dotbot_profiles() {
  local configs_dir="${1}"
  shopt -s nullglob
  local files=("${configs_dir}"/config*.yaml)
  shopt -u nullglob

  if (( ${#files[@]} == 0 )); then
    log_error "No Dotbot config files found in ${configs_dir}."
    return 1
  fi

  local file=""
  local label=""
  local description=""
  for file in "${files[@]}"; do
    label="$(basename "${file}")"
    if [[ "${label}" == "config.yaml" ]]; then
      label="default"
    else
      label="${label#config.}"
      label="${label%.yaml}"
    fi

    description="$(extract_dotbot_description "${file}")"
    printf '%s|%s|%s\n' "${label}" "${file}" "${description}"
  done | sort
}

handle_dotbot_list() {
  local configs_dir="${DEFAULT_DOTBOT_CONFIGS_DIR}"
  while (($#)); do
    case "${1}" in
      --configs-dir)
        configs_dir="${2:-}"
        if [[ -z "${configs_dir}" ]]; then
          log_error "--configs-dir requires a value."
          return 1
        fi
        shift 2
        ;;
      --help)
        cat <<EOF_HELP
Usage: ${SCRIPT_NAME} dotbot-list [--configs-dir DIR]

List available Dotbot profiles inferred from config*.yaml files.

Options:
  --configs-dir DIR       Directory that holds Dotbot config files.
  --help                  Show this help.
EOF_HELP
        return 0
        ;;
      *)
        log_error "Unknown option for dotbot-list: ${1}"
        return 1
        ;;
    esac
  done

  list_dotbot_profiles "${configs_dir}" | while IFS='|' read -r label file description; do
    printf '%-20s | %-70s | %s\n' "${label}" "${file}" "${description}"
  done
}

handle_dotbot_run() {
  local configs_dir="${DEFAULT_DOTBOT_CONFIGS_DIR}"
  local profile=""

  while (($#)); do
    case "${1}" in
      --configs-dir)
        configs_dir="${2:-}"
        if [[ -z "${configs_dir}" ]]; then
          log_error "--configs-dir requires a value."
          return 1
        fi
        shift 2
        ;;
      --profile)
        profile="${2:-}"
        if [[ -z "${profile}" ]]; then
          log_error "--profile requires a value."
          return 1
        fi
        shift 2
        ;;
      --help)
        cat <<EOF_HELP
Usage: ${SCRIPT_NAME} dotbot-run [--configs-dir DIR] [--profile NAME]

Run Dotbot using the existing helper script and a profile derived from config*.yaml.

Options:
  --configs-dir DIR       Directory that holds Dotbot config files.
  --profile NAME          Dotbot profile label (default, protected, etc).
  --help                  Show this help.

Behavior:
  * If --profile is omitted and gum is installed, a profile picker is shown.
  * The selected profile is passed to bashrc/helpers/dotbot.
EOF_HELP
        return 0
        ;;
      *)
        log_error "Unknown option for dotbot-run: ${1}"
        return 1
        ;;
    esac
  done

  if [[ ! -x "${DOTBOT_HELPER}" ]]; then
    log_error "Dotbot helper is missing or not executable: ${DOTBOT_HELPER}."
    return 1
  fi

  local profile_data=""
  profile_data="$(list_dotbot_profiles "${configs_dir}")"

  if [[ -z "${profile_data}" ]]; then
    log_error "No Dotbot profiles are available in ${configs_dir}."
    return 1
  fi

  if [[ -z "${profile}" ]]; then
    if command -v gum >/dev/null 2>&1; then
      local choice=""
      choice="$(printf '%s\n' "${profile_data}" | awk -F'|' '{printf "%s: %s\n", $1, $3}' | gum choose --header "Select Dotbot profile")"
      profile="${choice%%:*}"
      profile="${profile// /}"
    else
      log_error "--profile is required when gum is unavailable."
      return 1
    fi
  fi

  if ! printf '%s\n' "${profile_data}" | awk -F'|' '{print $1}' | grep -Fx "${profile}" >/dev/null 2>&1; then
    log_error "Unknown Dotbot profile '${profile}'. Use dotbot-list to inspect valid values."
    return 1
  fi

  if [[ "${profile}" == "default" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_msg "INFO" "[DRY-RUN] Would run ${DOTBOT_HELPER}."
    else
      "${DOTBOT_HELPER}"
    fi
  else
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_msg "INFO" "[DRY-RUN] Would run ${DOTBOT_HELPER} ${profile}."
    else
      "${DOTBOT_HELPER}" "${profile}"
    fi
  fi
}

main() {
  source_core_libs
  init_logging

  if (($# == 0)); then
    set -- menu
  fi

  while (($#)); do
    case "${1}" in
      --verbose)
        VERBOSE="true"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      --help)
        print_help
        return 0
        ;;
      *)
        break
        ;;
    esac
  done

  if (($# == 0)); then
    print_help
    return 1
  fi

  local command_name="${1}"
  shift

  log_debug "Command=${command_name} Args=$*"

  case "${command_name}" in
    menu)
      handle_menu "$@"
      ;;
    autostart-enable)
      handle_autostart_enable "$@"
      ;;
    autostart-disable)
      handle_autostart_disable "$@"
      ;;
    dotbot-list)
      handle_dotbot_list "$@"
      ;;
    dotbot-run)
      handle_dotbot_run "$@"
      ;;
    *)
      log_error "Unknown command: ${command_name}."
      print_help
      return 1
      ;;
  esac
}

main "$@"
