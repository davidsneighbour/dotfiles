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
#   - Uses the configured palette:
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

  case "${mode}" in
  none)
    printf ''
    ;;
  truecolor)
    case "${level}" in
    error) __dnb_rgb '255;149;128' ;;   # Red
    warn) __dnb_rgb '255;202;128' ;;    # Orange
    info) __dnb_rgb '128;255;234' ;;    # Cyan
    debug) __dnb_rgb '121;112;169' ;;   # Comment
    trace) __dnb_rgb '198;198;194' ;;   # DimWhite
    success) __dnb_rgb '138;255;128' ;; # Green
    dry) __dnb_rgb '255;255;128' ;;     # Yellow
    skip) __dnb_rgb '255;128;191' ;;    # Magenta
    *) __dnb_rgb '248;248;242' ;;       # Foreground
    esac
    ;;
  256)
    case "${level}" in
    error) __dnb_256 '217' ;;   # Red
    warn) __dnb_256 '222' ;;    # Orange
    info) __dnb_256 '159' ;;    # Cyan
    debug) __dnb_256 '103' ;;   # Comment
    trace) __dnb_256 '251' ;;   # DimWhite
    success) __dnb_256 '157' ;; # Green
    dry) __dnb_256 '229' ;;     # Yellow
    skip) __dnb_256 '218' ;;    # Magenta
    *) __dnb_256 '231' ;;       # Foreground
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
