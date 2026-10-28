# __dnb_color_mode

# DNB_COLOR_MODE=truecolor dnb_log info "Truecolour output"
# DNB_COLOR_MODE=256 dnb_log info "256-colour output"
# DNB_COLOR_MODE=basic dnb_log info "Basic ANSI output"
# DNB_COLOR_MODE=none dnb_log info "No colour output"
# NO_COLOR=1 dnb_log info "No colour output"

#
# Detect terminal colour support.
__dnb_color_mode() {
  if [[ -n "${NO_COLOR:-}" ]]; then
    printf 'none\n'
    return 0
  fi

  case "${DNB_COLOR_MODE:-auto}" in
  none | basic | 256 | truecolor)
    printf '%s\n' "${DNB_COLOR_MODE}"
    return 0
    ;;
  auto) ;;
  *)
    printf 'auto\n'
    ;;
  esac

  if [[ "${COLORTERM:-}" == 'truecolor' || "${COLORTERM:-}" == '24bit' ]]; then
    printf 'truecolor\n'
  elif [[ "${TERM:-}" == *'256color'* ]]; then
    printf '256\n'
  else
    printf 'basic\n'
  fi
}

# __dnb_rgb
#
# Print a truecolour foreground escape sequence.
__dnb_rgb() {
  local rgb="${1:-248;248;242}"
  printf '\033[38;2;%sm' "${rgb}"
}

# __dnb_256
#
# Print a 256-colour foreground escape sequence.
__dnb_256() {
  local color_id="${1:-231}"
  printf '\033[38;5;%sm' "${color_id}"
}

# __dnb_basic_color
#
# Print a basic ANSI foreground escape sequence.
__dnb_basic_color() {
  local level="${1:-info}"

  case "${level}" in
  error)
    printf '\033[31m'
    ;;
  warn | dry)
    printf '\033[33m'
    ;;
  info | debug | trace)
    printf '\033[36m'
    ;;
  success)
    printf '\033[32m'
    ;;
  skip)
    printf '\033[35m'
    ;;
  *)
    printf '\033[0m'
    ;;
  esac
}

# __dnb_log_color
#
# Resolve a log level to the best supported terminal colour.
#
# Parameters:
#   level  Log level: error, warn, info, debug, trace, success, dry, skip.
#
# Behaviour:
#   - Uses DNB_COLOR_MODE when set: auto, truecolor, 256, basic, none.
#   - Honours NO_COLOR by disabling colour.
#   - Uses the semantic roles from dnb-core-ui-theme.bash when loaded, so
#     DNB_UI_THEME applies. Falls back to these Nosferatu literals otherwise:
#     error   -> Red
#     warn    -> Orange
#     info    -> Cyan
#     debug   -> Comment
#     trace   -> DimWhite
#     success -> Green
#     dry     -> Yellow
#     skip    -> Magenta
__dnb_log_color() {
  local level="${1:-info}"
  local mode=''

  mode="$(__dnb_color_mode)"

  # Prefer the canonical theme tokens when the theme file is loaded. Resolve
  # them here, at call time, because the theme file loads after this file.
  if [[ "${mode}" == 'truecolor' || "${mode}" == '256' ]] && declare -F __dnb_ui_role_field >/dev/null; then
    local role='' value=''
    case "${level}" in
    error) role='error' ;;
    warn) role='warning' ;;
    info) role='info' ;;
    debug) role='muted' ;;
    trace) role='trace' ;;
    success) role='success' ;;
    dry) role='dry' ;;
    skip) role='skip' ;;
    *) role='fg' ;;
    esac
    if [[ "${mode}" == 'truecolor' ]]; then
      value="$(__dnb_ui_role_field "${role}" rgb)" && __dnb_rgb "${value}" && return 0
    else
      value="$(__dnb_ui_role_field "${role}" 256)" && __dnb_256 "${value}" && return 0
    fi
  fi

  case "${mode}" in
  none)
    printf ''
    ;;
  truecolor)
    case "${level}" in
    error) __dnb_rgb '255;125;108' ;;   # Red
    warn) __dnb_rgb '201;162;115' ;;    # Orange
    info) __dnb_rgb '166;186;192' ;;    # Cyan
    debug) __dnb_rgb '158;164;172' ;;   # Comment
    trace) __dnb_rgb '168;166;162' ;;   # DimWhite
    success) __dnb_rgb '155;175;132' ;; # Green
    dry) __dnb_rgb '242;200;97' ;;      # Yellow
    skip) __dnb_rgb '194;143;163' ;;    # Magenta
    *) __dnb_rgb '210;208;203' ;;       # Foreground
    esac
    ;;
  256)
    case "${level}" in
    error) __dnb_256 '209' ;;   # Red
    warn) __dnb_256 '179' ;;    # Orange
    info) __dnb_256 '249' ;;    # Cyan
    debug) __dnb_256 '248' ;;   # Comment
    trace) __dnb_256 '248' ;;   # DimWhite
    success) __dnb_256 '108' ;; # Green
    dry) __dnb_256 '221' ;;     # Yellow
    skip) __dnb_256 '139' ;;    # Magenta
    *) __dnb_256 '252' ;;       # Foreground
    esac
    ;;
  basic)
    __dnb_basic_color "${level}"
    ;;
  *)
    __dnb_basic_color "${level}"
    ;;
  esac
}
