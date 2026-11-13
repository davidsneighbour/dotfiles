#!/bin/bash
#
# Start and stop the Android emulator container on locutus, and show the
# device in a scrcpy window (or the noVNC web view).
#
# The public commands are bin/android-start and bin/android-stop. They call
# this script with the `start` or `stop` command. The container is defined in
# docker-compose.yaml beside this script. See README.md in this folder.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yaml"
CONTAINER_NAME='android-emulator'
# Host ports, published on 127.0.0.1 only (see docker-compose.yaml).
ADB_SERIAL='127.0.0.1:5600'
WEB_URL='http://127.0.0.1:3080/?autoconnect=true'
WINDOW_TITLE='Android emulator'
LOG_DIR="${HOME}/.logs/android-emulator"
DEFAULT_TIMEOUT='300'

android_source_libs() {
  local lib_dir="${DOTFILES_ROOT}/bashrc/lib/00-core"
  local lib=''

  for lib in dnb-core-colors dnb-core-log dnb-core-ui-theme dnb-core-ui; do
    if [[ ! -r "${lib_dir}/${lib}.bash" ]]; then
      printf 'Error: required library is missing: %s\n' "${lib_dir}/${lib}.bash" >&2
      exit 1
    fi
    # shellcheck source=/dev/null
    source "${lib_dir}/${lib}.bash"
  done
}

android_usage_main() {
  cat <<EOF
Usage: android-device.sh <command> [options]

Description:
  Start or stop the Android emulator container on locutus.
  Use the commands android-start and android-stop from PATH.

Options:
  -h, --help  Show this help and exit

Commands:
  start  Start the container and show the device (android-start)
  stop   Stop the container (android-stop)

Examples:
  android-device.sh start --help
  android-device.sh stop --help
EOF
}

android_usage_start() {
  cat <<EOF
Usage: android-start [options]

Description:
  Start the Android emulator container (Android 14, Galaxy S26 screen:
  1080x2340 at density 480, CSS viewport 360x780), wait until Android has
  booted, and show the device. If the container already runs, only the
  viewer is opened. Without options, this help is shown.

Options:
  --viewer <name>      Viewer to open: scrcpy, web, or none. Default: scrcpy
  --layout <name>      i3 placement of the scrcpy window: right or fullscreen. Default: right
  --timeout <seconds>  Maximum time to wait for the boot. Default: ${DEFAULT_TIMEOUT}
  --verbose            Show Docker, ADB, and scrcpy output
  --quiet              Show errors only (overrides --verbose and DNB_VERBOSE)
  -h, --help           Show this help and exit

Viewers:
  scrcpy  Native window through ADB (${ADB_SERIAL})
  web     noVNC in the browser (${WEB_URL})
  none    Start the container only

Layouts (scrcpy window in i3; the phone screen size does not change):
  right       Tiled at the right edge of the current workspace, full height,
              1/3 of the width. Alone on the workspace, it fills the workspace
  fullscreen  Fullscreen window

Logs:
  ${LOG_DIR}/YYYYMMDD-HHMMSS.log

Examples:
  android-start --viewer scrcpy
  android-start --viewer scrcpy --layout fullscreen
  android-start --viewer web
  android-start --viewer none --verbose
EOF
}

android_usage_stop() {
  cat <<EOF
Usage: android-stop [options]

Description:
  Close the device viewer, disconnect ADB, and remove the Android emulator
  container. Without options, this help is shown. Use --wipe-data after a
  change to emulator-override.ini or the device profile: these settings are
  only applied when the device is created.

Options:
  --keep-data  Keep apps, settings, and browser data for the next start (default)
  --wipe-data  Also delete the device data volumes (factory reset)
  --yes        Do not ask for confirmation before --wipe-data
  --verbose    Show Docker and ADB output
  --quiet      Show errors only (overrides --verbose and DNB_VERBOSE)
  -h, --help   Show this help and exit

Logs:
  ${LOG_DIR}/YYYYMMDD-HHMMSS.log

Examples:
  android-stop --keep-data
  android-stop --wipe-data
EOF
}

android_usage_error() {
  local usage_function="${1}"
  local message="${2}"

  printf 'Error: %s\n\n' "${message}" >&2
  "${usage_function}" >&2
  exit 2
}

android_apply_verbosity() {
  local quiet="${1}"

  if [[ "${quiet}" == 'true' ]]; then
    unset DNB_VERBOSE
    export DNB_UI_QUIET='1'
  fi
}

android_is_verbose() {
  [[ "${DNB_VERBOSE:-}" == '1' ]]
}

android_init_log() {
  if [[ -z "${DNB_SETUP_LOG_FILE:-}" ]]; then
    DNB_SETUP_LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S).log"
    export DNB_SETUP_LOG_FILE
  fi
  if ! mkdir -p "$(dirname "${DNB_SETUP_LOG_FILE}")"; then
    printf 'Error: cannot create the log folder for %s\n' "${DNB_SETUP_LOG_FILE}" >&2
    exit 1
  fi
  dnb_log_init >/dev/null
}

android_verbose() {
  if android_is_verbose; then
    dnb_log info "${*}"
  fi
}

# android_run COMMAND [ARG...]
#
# Run a command and append its output to the logfile. In verbose mode, also
# show the output on stderr. Returns the exit status of the command.
android_run() {
  android_verbose "Run: ${*}"
  if android_is_verbose; then
    "$@" 2>&1 | tee -a "${DNB_SETUP_LOG_FILE}" >&2
    return "${PIPESTATUS[0]}"
  fi
  "$@" >>"${DNB_SETUP_LOG_FILE}" 2>&1
}

android_fail() {
  dnb_ui_error "${1}"
  dnb_ui_error "Log: ${DNB_SETUP_LOG_FILE}"
  exit 1
}

android_require_commands() {
  local command_name=''

  for command_name in "$@"; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
      dnb_ui_error "Required command not found: ${command_name}. Install it and try again."
      exit 1
    fi
  done
  if [[ ! -r "${COMPOSE_FILE}" ]]; then
    dnb_ui_error "Compose file is missing or unreadable: ${COMPOSE_FILE}"
    exit 1
  fi
}

android_container_running() {
  local state=''

  if ! state="$(docker inspect --format '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null)"; then
    # docker inspect fails when the container does not exist.
    return 1
  fi
  [[ "${state}" == 'true' ]]
}

android_container_exists() {
  docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1
}

android_boot_completed() {
  local boot=''

  # Before the boot, ADB cannot reach the device and this command fails.
  # That is expected while we wait, so its error output is not shown.
  if ! boot="$(adb -s "${ADB_SERIAL}" shell getprop sys.boot_completed 2>/dev/null)"; then
    return 1
  fi
  [[ "${boot//$'\r'/}" == '1' ]]
}

android_wait_for_boot() {
  local timeout="${1}"
  local deadline=$((SECONDS + timeout))

  dnb_ui_info "Waiting for Android to boot (up to ${timeout} seconds)..."
  while ((SECONDS < deadline)); do
    if ! android_container_running; then
      android_fail "The container ${CONTAINER_NAME} stopped during the boot. Check: docker logs ${CONTAINER_NAME}"
    fi
    if ! android_run adb connect "${ADB_SERIAL}"; then
      android_verbose "adb connect ${ADB_SERIAL} failed; trying again"
    fi
    if android_boot_completed; then
      return 0
    fi
    sleep 3
  done
  android_fail "Android did not boot within ${timeout} seconds. Try a longer --timeout or check: docker logs ${CONTAINER_NAME}"
}

# Matches only the scrcpy process that android_open_scrcpy starts (its command
# line begins with this text), not other processes that mention it.
android_scrcpy_pattern() {
  printf '^scrcpy --serial=%s( |$)' "${ADB_SERIAL//./\\.}"
}

android_scrcpy_pids() {
  pgrep -f -- "$(android_scrcpy_pattern)"
}

android_open_scrcpy() {
  local layout="${1}"
  local pid=''

  if android_scrcpy_pids >/dev/null; then
    dnb_ui_info "The scrcpy window for ${ADB_SERIAL} is already open."
    return 0
  fi
  if [[ -z "${DISPLAY:-}" ]]; then
    android_fail "No graphical display (DISPLAY is not set). Use --viewer web or --viewer none."
  fi

  android_verbose "Open scrcpy for ${ADB_SERIAL}"
  # setsid detaches the window from this terminal, so it stays open after
  # this command exits. Its output goes to the logfile.
  setsid --wait scrcpy --serial="${ADB_SERIAL}" --window-title="${WINDOW_TITLE}" --no-audio \
    </dev/null >>"${DNB_SETUP_LOG_FILE}" 2>&1 &
  pid="${!}"
  sleep 2
  if ! kill -0 "${pid}" 2>/dev/null; then
    android_fail "scrcpy exited at once. Try: android-start --viewer web"
  fi
  dnb_ui_success "Opened the device window (scrcpy, ${ADB_SERIAL})."
  android_place_window "${layout}"
}

# jq program: for the i3 container with id $id, print one tab-separated line:
# the parent type, parent layout, whether the container is the parent's last
# child, the number of siblings (including itself), "floating" or "tiling",
# and the workspace name.
# shellcheck disable=SC2016 # $id and $p are jq variables, not shell variables.
ANDROID_I3_INFO_JQ='
  . as $root
  | first(paths(type == "object" and .id? == $id)) as $p
  | getpath($p[:-2]) as $parent
  | [range(0; $p | length) as $i | $root | getpath($p[:$i]) | select(type == "object" and .type? == "workspace")] as $workspaces
  | [$parent.type, $parent.layout, ($parent.nodes[-1].id == $id),
     ($parent.nodes | length), (if $parent.type == "floating_con" then "floating" else "tiling" end),
     ($workspaces | last | .name)]
  | @tsv'

android_i3_cmd() {
  local result=''

  android_verbose "i3-msg: ${1}"
  if ! result="$(i3-msg "${1}" 2>&1)" || ! printf '%s' "${result}" | jq -e 'all(.[]; .success)' >/dev/null 2>&1; then
    dnb_log warn "i3-msg command failed: ${1} (${result})"
    return 1
  fi
}

android_i3_window_id() {
  i3-msg -t get_tree | jq -r --arg title "${WINDOW_TITLE}" \
    'first(.. | objects | select(.window_properties?.class == "scrcpy" and .name == $title) | .id) // empty'
}

android_i3_window_info() {
  i3-msg -t get_tree | jq -r --argjson id "${1}" "${ANDROID_I3_INFO_JQ}"
}

# android_place_window LAYOUT
#
# right:      tile the window at the right edge of the current workspace,
#             full height and 1/3 of the width. Alone on the workspace, it
#             fills the workspace.
# fullscreen: make the window fullscreen.
# The phone screen itself does not change; scrcpy scales it into the window.
android_place_window() {
  local layout="${1}"
  local con_id=''
  local info=''
  local parent_type='' parent_layout='' is_last='' siblings='' mode='' workspace=''
  local start_workspace=''
  local attempt=0

  if ! command -v i3-msg >/dev/null 2>&1 || ! i3-msg -t get_version >/dev/null 2>&1; then
    android_verbose 'i3 is not running; the window is not placed.'
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    dnb_ui_warning 'jq not found; the window is not placed.'
    return 0
  fi

  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    con_id="$(android_i3_window_id)"
    [[ -n "${con_id}" ]] && break
    android_verbose "Waiting for the scrcpy window in i3 (attempt ${attempt})"
    sleep 0.5
  done
  if [[ -z "${con_id}" ]]; then
    dnb_ui_warning 'The scrcpy window was not found in i3; it is not placed.'
    return 0
  fi

  if [[ "${layout}" == 'fullscreen' ]]; then
    android_i3_cmd "[con_id=${con_id}] fullscreen enable" ||
      dnb_ui_warning 'Could not make the window fullscreen.'
    return 0
  fi

  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if ! info="$(android_i3_window_info "${con_id}" 2>>"${DNB_SETUP_LOG_FILE}")" || [[ -z "${info}" ]]; then
      dnb_ui_warning 'Could not read the i3 tree; the window is not placed.'
      return 0
    fi
    IFS=$'\t' read -r parent_type parent_layout is_last siblings mode workspace <<<"${info}"
    start_workspace="${start_workspace:-${workspace}}"
    android_verbose "Window: parent=${parent_type}/${parent_layout} last=${is_last} siblings=${siblings} mode=${mode} workspace=${workspace}"

    if [[ "${workspace}" != "${start_workspace}" ]]; then
      # i3 moves a window to the next output when it is already at the
      # right edge. Undo that and stop.
      android_i3_cmd "[con_id=${con_id}] move container to workspace ${start_workspace}, focus" ||
        dnb_ui_warning "The window moved to workspace ${workspace}."
      dnb_ui_warning 'Could not place the window at the right edge.'
      return 0
    fi
    if [[ "${mode}" == 'floating' ]]; then
      android_i3_cmd "[con_id=${con_id}] floating disable" || return 0
      continue
    fi
    if [[ "${parent_type}" == 'workspace' && "${siblings}" == '1' ]]; then
      android_verbose 'The window is alone on the workspace and fills it.'
      return 0
    fi
    if [[ "${parent_type}" == 'workspace' && "${parent_layout}" == 'splith' && "${is_last}" == 'true' ]]; then
      android_i3_cmd "[con_id=${con_id}] resize set width 33 ppt" ||
        dnb_ui_warning 'Could not resize the window.'
      return 0
    fi
    # Each step moves the window one level out of its containers. At
    # workspace level, i3 makes the workspace a horizontal split first.
    android_i3_cmd "[con_id=${con_id}] move right" || return 0
  done
  dnb_ui_warning 'Could not place the window at the right edge after 10 steps.'
}

android_open_web() {
  if ! command -v xdg-open >/dev/null 2>&1; then
    dnb_ui_warning "xdg-open not found. Open ${WEB_URL} in a browser."
    return 0
  fi
  # xdg-open can stay in the foreground until the browser exits, so it is
  # detached. Its output goes to the logfile.
  setsid -f xdg-open "${WEB_URL}" </dev/null >>"${DNB_SETUP_LOG_FILE}" 2>&1
  dnb_ui_success "Opened the web view: ${WEB_URL}"
}

android_cmd_start() {
  local viewer=''
  local layout=''
  local timeout="${DEFAULT_TIMEOUT}"
  local quiet='false'

  if [[ "$#" -eq 0 ]]; then
    android_usage_start
    exit 0
  fi
  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    -h | --help)
      android_usage_start
      exit 0
      ;;
    --viewer)
      [[ "$#" -ge 2 ]] || android_usage_error android_usage_start '--viewer needs a value'
      viewer="${2}"
      shift 2
      ;;
    --viewer=*)
      viewer="${1#*=}"
      shift
      ;;
    --layout)
      [[ "$#" -ge 2 ]] || android_usage_error android_usage_start '--layout needs a value'
      layout="${2}"
      shift 2
      ;;
    --layout=*)
      layout="${1#*=}"
      shift
      ;;
    --timeout)
      [[ "$#" -ge 2 ]] || android_usage_error android_usage_start '--timeout needs a value'
      timeout="${2}"
      shift 2
      ;;
    --timeout=*)
      timeout="${1#*=}"
      shift
      ;;
    --verbose)
      export DNB_VERBOSE='1'
      shift
      ;;
    --quiet)
      quiet='true'
      shift
      ;;
    *)
      android_usage_error android_usage_start "unknown option: ${1}"
      ;;
    esac
  done

  viewer="${viewer:-scrcpy}"
  case "${viewer}" in
  scrcpy | web | none) ;;
  *) android_usage_error android_usage_start "--viewer must be scrcpy, web, or none (got: ${viewer})" ;;
  esac
  layout="${layout:-right}"
  case "${layout}" in
  right | fullscreen) ;;
  *) android_usage_error android_usage_start "--layout must be right or fullscreen (got: ${layout})" ;;
  esac
  if [[ ! "${timeout}" =~ ^[1-9][0-9]*$ ]]; then
    android_usage_error android_usage_start "--timeout must be a positive number of seconds (got: ${timeout})"
  fi

  android_apply_verbosity "${quiet}"
  android_init_log
  if [[ "${viewer}" == 'scrcpy' ]]; then
    android_require_commands docker adb scrcpy setsid
  else
    android_require_commands docker adb
  fi
  if [[ ! -e /dev/kvm ]]; then
    dnb_ui_error '/dev/kvm not found. Enable CPU virtualisation (KVM) and try again.'
    exit 1
  fi

  if android_container_running; then
    dnb_ui_info "The container ${CONTAINER_NAME} already runs."
  else
    dnb_ui_info "Starting the container ${CONTAINER_NAME}..."
    if ! android_run docker compose --file "${COMPOSE_FILE}" up --detach; then
      android_fail "docker compose up failed. Check that ports 5600 and 3080 on 127.0.0.1 are free."
    fi
  fi

  android_wait_for_boot "${timeout}"
  dnb_ui_success "Android is ready. ADB: ${ADB_SERIAL}"

  case "${viewer}" in
  scrcpy) android_open_scrcpy "${layout}" ;;
  web) android_open_web ;;
  none) dnb_ui_info "No viewer opened. Web view: ${WEB_URL}" ;;
  *) android_fail "Unknown viewer: ${viewer}" ;;
  esac
}

android_close_viewer() {
  local pids=''

  if ! pids="$(android_scrcpy_pids)"; then
    android_verbose 'No scrcpy window is open.'
    return 0
  fi
  android_verbose "Close scrcpy (PID ${pids//$'\n'/, })"
  if ! pkill -f -- "$(android_scrcpy_pattern)"; then
    dnb_ui_warning 'Could not close the scrcpy window. It closes when the device stops.'
  fi
}

android_disconnect_adb() {
  if ! adb devices 2>>"${DNB_SETUP_LOG_FILE}" | grep -q -F -- "${ADB_SERIAL}"; then
    android_verbose "ADB is not connected to ${ADB_SERIAL}."
    return 0
  fi
  if ! android_run adb disconnect "${ADB_SERIAL}"; then
    dnb_ui_warning "adb disconnect ${ADB_SERIAL} failed."
  fi
}

# Shut the emulator down through its console, so Android writes its data to
# disk. Without this, Docker kills the emulator when the container stops.
android_shutdown_emulator() {
  local deadline=$((SECONDS + 60))

  if ! android_container_running; then
    return 0
  fi
  if ! android_run docker exec "${CONTAINER_NAME}" adb -s emulator-5554 emu kill; then
    dnb_ui_warning 'Could not shut the emulator down cleanly. The container is stopped anyway.'
    return 0
  fi
  while ((SECONDS < deadline)); do
    if ! docker exec "${CONTAINER_NAME}" pgrep -x qemu-system-x86 >/dev/null 2>>"${DNB_SETUP_LOG_FILE}"; then
      android_verbose 'The emulator has shut down.'
      return 0
    fi
    sleep 1
  done
  dnb_ui_warning 'The emulator did not shut down within 60 seconds. The container is stopped anyway.'
}

android_confirm_wipe() {
  local status=0

  dnb_ui_confirm --prompt 'Delete all Android emulator data (apps, settings, and browser data)?' || status=$?
  case "${status}" in
  0) return 0 ;;
  3)
    dnb_ui_error 'Cannot ask for confirmation without a terminal. Add --yes to delete the data.'
    exit 1
    ;;
  *)
    dnb_ui_info 'Cancelled. Nothing was stopped or deleted.'
    exit 1
    ;;
  esac
}

android_cmd_stop() {
  local data_mode=''
  local assume_yes='false'
  local quiet='false'
  local -a down_args=(--file "${COMPOSE_FILE}" down)

  if [[ "$#" -eq 0 ]]; then
    android_usage_stop
    exit 0
  fi
  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    -h | --help)
      android_usage_stop
      exit 0
      ;;
    --keep-data | --wipe-data)
      if [[ -n "${data_mode}" && "${data_mode}" != "${1}" ]]; then
        android_usage_error android_usage_stop 'use either --keep-data or --wipe-data, not both'
      fi
      data_mode="${1}"
      shift
      ;;
    --yes)
      assume_yes='true'
      shift
      ;;
    --verbose)
      export DNB_VERBOSE='1'
      shift
      ;;
    --quiet)
      quiet='true'
      shift
      ;;
    *)
      android_usage_error android_usage_stop "unknown option: ${1}"
      ;;
    esac
  done

  data_mode="${data_mode:---keep-data}"
  android_apply_verbosity "${quiet}"
  android_init_log
  android_require_commands docker adb

  if [[ "${data_mode}" == '--wipe-data' ]]; then
    if [[ "${assume_yes}" != 'true' ]]; then
      android_confirm_wipe
    fi
    down_args+=(--volumes)
  elif ! android_container_exists; then
    dnb_ui_info "The container ${CONTAINER_NAME} does not run. Nothing to stop."
    return 0
  fi

  android_close_viewer
  android_disconnect_adb

  dnb_ui_info "Stopping the container ${CONTAINER_NAME}..."
  android_shutdown_emulator
  if ! android_run docker compose "${down_args[@]}"; then
    android_fail 'docker compose down failed.'
  fi
  if [[ "${data_mode}" == '--wipe-data' ]]; then
    dnb_ui_success 'Stopped the Android emulator and deleted its data.'
  else
    dnb_ui_success 'Stopped the Android emulator. Its data is kept for the next start.'
  fi
}

android_main() {
  local command_name="${1:-}"

  case "${command_name}" in
  '' | -h | --help)
    android_usage_main
    exit 0
    ;;
  start | stop)
    shift
    android_source_libs
    "android_cmd_${command_name}" "$@"
    ;;
  *)
    android_usage_error android_usage_main "unknown command: ${command_name}"
    ;;
  esac
}

android_main "$@"
