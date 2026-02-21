#!/bin/bash
# xfce-workspaces.sh
# Configure XFCE (xfwm4) workspaces and optionally start apps on specific workspaces.

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

VERBOSE=0
WORKSPACE_COUNT=""
WORKSPACE_NAMES_CSV=""
START_SPECS=()
MOVE_SPECS=()

log() {
  if [[ "${VERBOSE}" -eq 1 ]]; then
    printf '%s\n' "$*" >&2
  fi
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  printf '\n' >&2
  print_help >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  if ! have_cmd "$1"; then
    die "Missing dependency: ${1}. Install it (apt): sudo apt install ${1}"
  fi
}

print_help() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} [--count N] [--names "A,B,C"] [--start "IDX:CMD"]... [--move "IDX:REGEX"]... [--verbose] [--help]

Options:
  --count N
    Set number of workspaces (desktops) to N.

  --names "A,B,C"
    Set workspace names as a comma-separated list.
    If fewer names than --count, remaining names are auto-filled as "Workspace X".
    If more names than --count, extra names are ignored.

  --start "IDX:CMD"
    Start CMD on workspace IDX (0-based index).
    Example: --start "1:firefox" --start "2:code"

    Implementation:
      1) switch to workspace IDX via wmctrl
      2) launch CMD (nohup in background)

  --move "IDX:REGEX"
    Move the first window whose wmctrl listing matches REGEX to workspace IDX.
    This is optional and helps with apps that do not reliably open on the current workspace.
    Example: --move "1:Firefox" --move "2:Visual Studio Code"

  --verbose
    Print extra information.

  --help
    Show this help.

Examples:
  # 4 workspaces, named, start apps on specific workspaces
  ${SCRIPT_NAME} --count 4 --names "Web,Code,Comms,Ops" \\
    --start "0:firefox" --start "1:code" --start "2:thunderbird" --start "3:xfce4-terminal"

  # Same, but also force-move matching windows after launch
  ${SCRIPT_NAME} --count 4 --names "Web,Code,Comms,Ops" \\
    --start "0:firefox" --move "0:Firefox" \\
    --start "1:code" --move "1:Visual Studio Code"

Notes:
  * This is for XFCE/xfwm4 on X11.
  * Workspace index is 0-based (wmctrl convention).
EOF
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    print_help
    exit 0
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --help)
      print_help
      exit 0
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --count)
      [[ $# -ge 2 ]] || die "--count requires a value"
      WORKSPACE_COUNT="$2"
      shift 2
      ;;
    --names)
      [[ $# -ge 2 ]] || die "--names requires a value"
      WORKSPACE_NAMES_CSV="$2"
      shift 2
      ;;
    --start)
      [[ $# -ge 2 ]] || die "--start requires a value"
      START_SPECS+=("$2")
      shift 2
      ;;
    --move)
      [[ $# -ge 2 ]] || die "--move requires a value"
      MOVE_SPECS+=("$2")
      shift 2
      ;;
    *)
      die "Unknown option: $1"
      ;;
    esac
  done
}

is_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

xfconf_get_count() {
  xfconf-query -c xfwm4 -p /general/workspace_count
}

xfconf_set_count() {
  local count="$1"
  xfconf-query -c xfwm4 -p /general/workspace_count -s "${count}"
}

xfconf_get_names_raw() {
  xfconf-query -c xfwm4 -p /general/workspace_names
}

# Returns names as newline-separated list, skipping the "Value is an array..." header if present.
xfconf_get_names_list() {
  local raw
  raw="$(xfconf_get_names_raw 2>/dev/null || true)"

  # Typical output starts with:
  # "Value is an array with N items:" then names line by line.
  # If it's already a single line or different, we still handle it.
  if printf '%s\n' "${raw}" | head -n 1 | grep -q '^Value is an array'; then
    printf '%s\n' "${raw}" | tail -n +3
  else
    # If it's not an array header, emit raw as-is (best effort).
    printf '%s\n' "${raw}"
  fi
}

xfconf_set_names_from_array() {
  # Takes bash array by name
  local -n _names_ref="$1"

  local args=()
  local name

  # Set the whole array in one go (xfconf-query stores it as an array if multiple -s are used).
  for name in "${_names_ref[@]}"; do
    args+=(-s "${name}")
  done

  log "Setting workspace names: ${_names_ref[*]}"
  xfconf-query -c xfwm4 -p /general/workspace_names "${args[@]}"
}

split_csv_to_array() {
  local csv="$1"
  local -n _out="$2"

  # Simple CSV split on commas; trim leading/trailing spaces.
  # If you need commas inside names, switch to a different encoding.
  IFS=',' read -r -a _out <<<"${csv}"

  local i
  for i in "${!_out[@]}"; do
    _out[$i]="$(printf '%s' "${_out[$i]}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  done
}

ensure_names_length() {
  local count="$1"
  local -n _names="$2"

  local i
  if ((${#_names[@]} < count)); then
    for ((i = ${#_names[@]}; i < count; i++)); do
      _names+=("Workspace $((i + 1))")
    done
  elif ((${#_names[@]} > count)); then
    _names=("${_names[@]:0:count}")
  fi
}

wmctrl_current_desktop() {
  wmctrl -d | awk '$2=="*" {print $1; exit}'
}

wmctrl_switch_desktop() {
  local idx="$1"
  wmctrl -s "${idx}"
}

start_on_workspace() {
  local idx="$1"
  local cmd="$2"

  log "Switching to workspace ${idx} and starting: ${cmd}"

  wmctrl_switch_desktop "${idx}"

  # Wait until WM really switched
  local tries=40
  while ((tries > 0)); do
    if [[ "$(wmctrl_current_desktop)" == "${idx}" ]]; then
      break
    fi
    tries=$((tries - 1))
    sleep 0.05
  done

  if [[ "$(wmctrl_current_desktop)" != "${idx}" ]]; then
    log "Warning: workspace switch to ${idx} not confirmed, launching anyway"
  fi

  # Launch after switch is confirmed
  nohup bash -lc "${cmd}" >/dev/null 2>&1 &
}

move_first_matching_window_to_workspace() {
  local idx="$1"
  local regex="$2"

  # Wait a bit for windows to appear, but do not sleep blindly for 5s.
  # Try up to ~4s in short intervals.
  local tries=40
  local line=""
  local win_id=""

  while ((tries > 0)); do
    # wmctrl -l output: WIN_ID DESK HOST TITLE...
    # We pick the first line that matches regex.
    line="$(wmctrl -l | grep -E "${regex}" | head -n 1 || true)"
    if [[ -n "${line}" ]]; then
      win_id="$(printf '%s\n' "${line}" | awk '{print $1}')"
      break
    fi
    tries=$((tries - 1))
    sleep 0.1
  done

  if [[ -z "${win_id}" ]]; then
    log "No window matched regex '${regex}', skipping move."
    return 0
  fi

  log "Moving window ${win_id} (matched '${regex}') to workspace ${idx}"
  wmctrl -i -r "${win_id}" -t "${idx}"
}

main() {
  parse_args "$@"

  require_cmd xfconf-query

  if [[ -n "${WORKSPACE_COUNT}" ]]; then
    is_int "${WORKSPACE_COUNT}" || die "--count must be an integer"
  fi

  # Only require wmctrl if we actually need it
  if ((${#START_SPECS[@]} > 0 || ${#MOVE_SPECS[@]} > 0)); then
    require_cmd wmctrl
  fi

  # Apply workspace count if requested
  if [[ -n "${WORKSPACE_COUNT}" ]]; then
    log "Current workspace count: $(xfconf_get_count)"
    xfconf_set_count "${WORKSPACE_COUNT}"
    log "New workspace count: $(xfconf_get_count)"
  fi

  # Apply names if requested
  if [[ -n "${WORKSPACE_NAMES_CSV}" ]]; then
    local_count="$(xfconf_get_count)"
    is_int "${local_count}" || die "Could not read current workspace count from xfconf"

    declare -a names=()
    split_csv_to_array "${WORKSPACE_NAMES_CSV}" names
    ensure_names_length "${local_count}" names
    xfconf_set_names_from_array names
  fi

  # Start apps on workspaces
  local original_desktop=""
  if ((${#START_SPECS[@]} > 0)); then
    original_desktop="$(wmctrl_current_desktop)"
  fi

  for spec in "${START_SPECS[@]}"; do
    # Format: IDX:CMD
    idx="${spec%%:*}"
    cmd="${spec#*:}"
    [[ -n "${idx}" && -n "${cmd}" && "${spec}" == *:* ]] || die "Invalid --start spec: ${spec}"
    is_int "${idx}" || die "Invalid workspace index in --start: ${idx}"
    start_on_workspace "${idx}" "${cmd}"
  done

  # Move matching windows to workspaces (optional)
  for spec in "${MOVE_SPECS[@]}"; do
    idx="${spec%%:*}"
    regex="${spec#*:}"
    [[ -n "${idx}" && -n "${regex}" && "${spec}" == *:* ]] || die "Invalid --move spec: ${spec}"
    is_int "${idx}" || die "Invalid workspace index in --move: ${idx}"
    move_first_matching_window_to_workspace "${idx}" "${regex}"
  done

  # Go back to the original workspace if we switched during startup
  if [[ -n "${original_desktop}" ]]; then
    log "Switching back to original workspace ${original_desktop}"
    wmctrl_switch_desktop "${original_desktop}"
  fi
}

main "$@"
