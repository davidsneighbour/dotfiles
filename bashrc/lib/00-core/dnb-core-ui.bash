# shellcheck shell=bash

# DNB terminal UI facade.
#
# Business logic describes intent through these functions. They own
# presentation, capability checks, backend choice (Gum, fzf, Glow, bat, delta),
# and plain fallbacks. See docs/terminal-ui.md for the full contract.
#
# Streams:
#   stdout  command results only (selected values, answers, tables, documents)
#   stderr  headings, messages, prompts, progress, and diagnostics
#
# Environment:
#   DNB_UI_FORMAT=auto|plain|json   output format (helpers map --plain/--json)
#   DNB_UI_QUIET=1                  suppress routine UI and progress
#   DNB_UI_THEME, DNB_UI_SYMBOLS    see dnb-core-ui-theme.bash
#   DNB_COLOR_MODE, NO_COLOR        see dnb-core-colors.bash
#
# Interaction return codes:
#   0 accepted, 1 declined or no match, 2 invalid arguments or backend error,
#   3 required input missing (non-interactive or backend unavailable),
#   130 cancelled.
#
# Sourcing this file only defines functions. It needs dnb-core-ui-theme.bash,
# dnb-core-colors.bash, and dnb-core-log.bash at call time.

# dnb_ui_mode
#
# Print the resolved output format: json, plain, or auto.
# Priority: json over plain over automatic presentation. TERM=dumb is plain.
dnb_ui_mode() {
  case "${DNB_UI_FORMAT:-auto}" in
  json) printf 'json\n' ;;
  plain) printf 'plain\n' ;;
  *)
    if [[ "${TERM:-}" == 'dumb' ]]; then
      printf 'plain\n'
    else
      printf 'auto\n'
    fi
    ;;
  esac
}

# dnb_ui_is_interactive
#
# Return 0 when questions can be asked: stdin and stderr are terminals, the
# format is not JSON, and the terminal is not dumb. Command substitution of
# stdout does not prevent interaction.
dnb_ui_is_interactive() {
  [[ -t 0 && -t 2 && "${TERM:-}" != 'dumb' ]] || return 1
  [[ "$(dnb_ui_mode)" != 'json' ]]
}

# dnb_ui_supports_color [--fd N]
#
# Return 0 when file descriptor N (default 2) may receive colour escapes.
# A forced DNB_COLOR_MODE never forces escapes into plain, JSON, or
# redirected output.
dnb_ui_supports_color() {
  local fd='2'

  if [[ "${1:-}" == '--fd' ]]; then
    fd="${2:-}"
  fi
  [[ "${fd}" =~ ^[0-9]+$ ]] || return 2

  [[ "$(dnb_ui_mode)" == 'auto' ]] || return 1
  [[ -t "${fd}" ]] || return 1
  [[ "$(__dnb_color_mode)" != 'none' ]]
}

# dnb_ui_symbol NAME
#
# Print one semantic symbol without colour. NAME: success, error, warning,
# action, item, prompt, rule, created, changed, removed.
dnb_ui_symbol() {
  local name="${1:-}"
  local row="${__DNB_UI_SYMBOLS[${name}]:-}"

  if [[ -z "${row}" ]]; then
    printf 'dnb_ui_symbol: unknown symbol: %s\n' "${name}" >&2
    return 2
  fi
  if __dnb_ui_unicode; then
    printf '%s' "${row%%|*}"
  else
    printf '%s' "${row#*|}"
  fi
}

# __dnb_ui_unicode
#
# Return 0 when Unicode symbols should be used.
__dnb_ui_unicode() {
  case "${DNB_UI_SYMBOLS:-auto}" in
  unicode) return 0 ;;
  ascii) return 1 ;;
  *) ;;
  esac
  [[ "$(dnb_ui_mode)" == 'auto' ]] || return 1
  local locale="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
  [[ "${locale}" == *[Uu][Tt][Ff]-8* || "${locale}" == *[Uu][Tt][Ff]8* ]]
}

# __dnb_ui_quiet
#
# Return 0 when routine UI is suppressed.
__dnb_ui_quiet() {
  [[ "${DNB_UI_QUIET:-}" == '1' ]]
}

# __dnb_ui_width
#
# Print a usable layout width, clamped to 20..100. Falls back to 80.
__dnb_ui_width() {
  local width="${COLUMNS:-80}"

  [[ "${width}" =~ ^[0-9]+$ ]] || width='80'
  ((width < 20)) && width='20'
  ((width > 100)) && width='100'
  printf '%s\n' "${width}"
}

# __dnb_ui_sgr ROLE FD
#
# Print the foreground escape for ROLE when FD supports colour, else nothing.
# Callers inside $(...) must not pass FD 1; see dnb_ui_style_code.
__dnb_ui_sgr() {
  local role="${1:?role required}"
  local fd="${2:-2}"

  dnb_ui_supports_color --fd "${fd}" || return 0
  __dnb_ui_sgr_raw "${role}"
}

# __dnb_ui_sgr_raw ROLE
#
# Print the foreground escape for ROLE for the current colour depth, without
# a capability check.
__dnb_ui_sgr_raw() {
  local role="${1:?role required}"
  local value=''

  case "$(__dnb_color_mode)" in
  none) return 0 ;;
  truecolor)
    value="$(__dnb_ui_role_field "${role}" rgb)" || return 0
    printf '\033[38;2;%sm' "${value}"
    ;;
  256)
    value="$(__dnb_ui_role_field "${role}" 256)" || return 0
    printf '\033[38;5;%sm' "${value}"
    ;;
  *)
    value="$(__dnb_ui_role_field "${role}" basic)" || return 0
    printf '\033[%sm' "${value}"
    ;;
  esac
}

# __dnb_ui_reset FD
#
# Print the reset escape only when FD supports colour.
__dnb_ui_reset() {
  dnb_ui_supports_color --fd "${1:-2}" || return 0
  printf '\033[0m'
}

# dnb_ui_style_code VAR ROLE|bold|dim|reset [--fd N]
#
# Set VAR to the escape for a semantic role, bold, dim, or reset when fd N
# (default 1) supports colour, else to an empty string. For helpers that
# colour parts of their own layout (for example single table cells): fetch
# the codes once, pad text first, then add them. Sets VAR instead of
# printing, because command substitution would hide the real stdout.
dnb_ui_style_code() {
  local __var="${1:-}"
  local __name="${2:-}"
  local __fd='1'
  local __code=''

  if [[ ! "${__var}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    printf 'dnb_ui_style_code: invalid variable name: %s\n' "${__var}" >&2
    return 2
  fi
  if [[ "${3:-}" == '--fd' ]]; then
    __fd="${4:-}"
  fi
  [[ "${__fd}" =~ ^[0-9]+$ ]] || return 2
  case "${__name}" in
  bold | dim | reset) ;;
  *)
    if [[ -z "${__DNB_UI_ROLES[${__name}]:-}" ]]; then
      printf 'dnb_ui_style_code: unknown role: %s\n' "${__name}" >&2
      return 2
    fi
    ;;
  esac

  printf -v "${__var}" '%s' ''
  dnb_ui_supports_color --fd "${__fd}" || return 0
  case "${__name}" in
  bold) __code=$'\033[1m' ;;
  dim) __code=$'\033[2m' ;;
  reset) __code=$'\033[0m' ;;
  *) __code="$(__dnb_ui_sgr_raw "${__name}")" ;;
  esac
  printf -v "${__var}" '%s' "${__code}"
}

# __dnb_ui_backend_color ROLE
#
# Print ROLE as a colour value for Gum or fzf: hex in truecolor mode, the
# 256-colour index in 256 mode, or an ANSI slot (0-15) in basic mode.
__dnb_ui_backend_color() {
  local role="${1:?role required}"
  local sgr=''

  case "$(__dnb_color_mode)" in
  truecolor) __dnb_ui_role_field "${role}" hex ;;
  256) __dnb_ui_role_field "${role}" 256 ;;
  *)
    sgr="$(__dnb_ui_role_field "${role}" basic)" || return 1
    if ((sgr >= 30 && sgr <= 37)); then
      printf '%s\n' "$((sgr - 30))"
    elif ((sgr >= 90 && sgr <= 97)); then
      printf '%s\n' "$((sgr - 82))"
    else
      printf '\n'
    fi
    ;;
  esac
}

# __dnb_ui_has TOOL
#
# Return 0 when TOOL is on PATH and DNB_UI_DISABLE does not list it.
# DNB_UI_DISABLE is a space-separated list used by tests and for opting out.
__dnb_ui_has() {
  local tool="${1:?tool required}"

  [[ " ${DNB_UI_DISABLE:-} " != *" ${tool} "* ]] || return 1
  command -v "${tool}" >/dev/null 2>&1
}

# __dnb_ui_check_text CALLER TEXT
#
# Reject terminal control characters in labels, prompts, and options.
__dnb_ui_check_text() {
  local caller="${1}"
  local text="${2-}"

  if [[ "${text}" == *[[:cntrl:]]* ]]; then
    printf '%s: control characters are not allowed in labels\n' "${caller}" >&2
    return 2
  fi
}

# __dnb_ui_lib_root
#
# Print the repository root derived from this file's location.
__dnb_ui_lib_root() {
  local dir=''
  dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)" || return 1
  printf '%s\n' "${dir}"
}

# dnb_ui_heading TEXT...
#
# Print a heading on stderr. Several arguments become several lines.
dnb_ui_heading() {
  local line=''

  __dnb_ui_quiet && return 0
  for line in "$@"; do
    __dnb_ui_check_text "${FUNCNAME[0]}" "${line}" || return 2
  done

  if dnb_ui_supports_color --fd 2 && __dnb_ui_unicode && __dnb_ui_has gum; then
    gum style \
      --foreground "$(__dnb_ui_backend_color accent)" \
      --border-foreground "$(__dnb_ui_backend_color border)" \
      --border double \
      --align center \
      --width "$(__dnb_ui_width)" \
      --padding '0 1' \
      -- "$@" >&2
    return
  fi

  for line in "$@"; do
    printf '%s== %s ==%s\n' "$(__dnb_ui_sgr accent 2)" "${line}" "$(__dnb_ui_reset 2)" >&2
  done
}

# dnb_ui_subheading TEXT
#
# Print a subheading on stderr.
dnb_ui_subheading() {
  __dnb_ui_quiet && return 0
  __dnb_ui_check_text "${FUNCNAME[0]}" "${1-}" || return 2
  printf '%s%s %s%s\n' "$(__dnb_ui_sgr accent 2)" "$(dnb_ui_symbol action)" "${1-}" "$(__dnb_ui_reset 2)" >&2
}

# dnb_ui_rule
#
# Print a horizontal rule on stderr.
dnb_ui_rule() {
  local width='' symbol='' line=''
  local i=0

  __dnb_ui_quiet && return 0
  width="$(__dnb_ui_width)"
  symbol="$(dnb_ui_symbol rule)"
  for ((i = 0; i < width; i++)); do
    line+="${symbol}"
  done
  printf '%s%s%s\n' "$(__dnb_ui_sgr border 2)" "${line}" "$(__dnb_ui_reset 2)" >&2
}

# __dnb_ui_log LEVEL TEXT
#
# Send a message through dnb_log (stderr), colourless when stderr cannot
# take colour. Keeps dnb_log's logfile behaviour.
__dnb_ui_log() {
  local level="${1}"
  local text="${2-}"

  if ! declare -F dnb_log >/dev/null; then
    printf '[%s] %s\n' "${level}" "${text}" >&2
    return 0
  fi
  if dnb_ui_supports_color --fd 2; then
    dnb_log "${level}" "${text}"
  else
    DNB_COLOR_MODE='none' dnb_log "${level}" "${text}"
  fi
}

# dnb_ui_info TEXT / dnb_ui_success TEXT / dnb_ui_warning TEXT / dnb_ui_error TEXT
#
# Semantic messages on stderr. Quiet mode suppresses info and success.
dnb_ui_info() {
  __dnb_ui_quiet && return 0
  __dnb_ui_log info "$*"
}

dnb_ui_success() {
  __dnb_ui_quiet && return 0
  __dnb_ui_log success "$*"
}

dnb_ui_warning() {
  __dnb_ui_log warn "$*"
}

dnb_ui_error() {
  __dnb_ui_log error "$*"
}

# __dnb_ui_map_status STATUS
#
# Map a Gum/fzf exit status to the facade return codes.
__dnb_ui_map_status() {
  case "${1}" in
  0) return 0 ;;
  1) return 1 ;;
  130) return 130 ;;
  *) return 2 ;;
  esac
}

# __dnb_ui_require_interactive CALLER
#
# Fail with code 3 and a short message when no question can be asked.
__dnb_ui_require_interactive() {
  dnb_ui_is_interactive && return 0
  printf '%s: input required, but no interactive terminal is available\n' "${1}" >&2
  return 3
}

# __dnb_ui_use_gum
#
# Return 0 when Gum widgets may be used.
__dnb_ui_use_gum() {
  [[ "$(dnb_ui_mode)" == 'auto' ]] && __dnb_ui_has gum
}

# dnb_ui_input --prompt TEXT [--default TEXT]
#
# Ask for one line. The answer goes to stdout; the prompt goes to stderr.
# An empty answer uses --default when given. Non-interactive use returns 3.
dnb_ui_input() {
  local prompt='' default='' answer='' status=0

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    --prompt) prompt="${2-}" && shift 2 || return 2 ;;
    --default) default="${2-}" && shift 2 || return 2 ;;
    *)
      printf '%s: unknown argument: %s\n' "${FUNCNAME[0]}" "${1}" >&2
      return 2
      ;;
    esac
  done
  [[ -n "${prompt}" ]] || { printf '%s: --prompt is required\n' "${FUNCNAME[0]}" >&2 && return 2; }
  __dnb_ui_check_text "${FUNCNAME[0]}" "${prompt}" || return 2
  __dnb_ui_require_interactive "${FUNCNAME[0]}" || return

  if __dnb_ui_use_gum; then
    answer="$(gum input \
      --prompt "$(dnb_ui_symbol prompt) ${prompt} " \
      --placeholder "${default}" \
      --prompt.foreground "$(__dnb_ui_backend_color accent)" \
      --cursor.foreground "$(__dnb_ui_backend_color cursor)")" || status=$?
    __dnb_ui_map_status "${status}" || return
  else
    if [[ -n "${default}" ]]; then
      printf '%s %s [%s]: ' "$(dnb_ui_symbol prompt)" "${prompt}" "${default}" >&2
    else
      printf '%s %s: ' "$(dnb_ui_symbol prompt)" "${prompt}" >&2
    fi
    IFS= read -r answer || return 130
  fi

  [[ -n "${answer}" ]] || answer="${default}"
  printf '%s\n' "${answer}"
}

# dnb_ui_confirm --prompt TEXT [--default no]
#
# Ask a yes/no question. Returns 0 only on explicit acceptance, 1 on "no" or
# an empty answer, 3 when non-interactive, and 130 on cancel. Prints nothing
# on stdout. The default is always "no".
dnb_ui_confirm() {
  local prompt='' answer='' status=0

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    --prompt) prompt="${2-}" && shift 2 || return 2 ;;
    --default)
      if [[ "${2-}" != 'no' ]]; then
        printf '%s: only --default no is supported\n' "${FUNCNAME[0]}" >&2
        return 2
      fi
      shift 2
      ;;
    *)
      printf '%s: unknown argument: %s\n' "${FUNCNAME[0]}" "${1}" >&2
      return 2
      ;;
    esac
  done
  [[ -n "${prompt}" ]] || { printf '%s: --prompt is required\n' "${FUNCNAME[0]}" >&2 && return 2; }
  __dnb_ui_check_text "${FUNCNAME[0]}" "${prompt}" || return 2
  __dnb_ui_require_interactive "${FUNCNAME[0]}" || return

  if __dnb_ui_use_gum; then
    gum confirm \
      --default=false \
      --prompt.foreground "$(__dnb_ui_backend_color fg)" \
      --selected.background "$(__dnb_ui_backend_color accent)" \
      --selected.foreground "$(__dnb_ui_backend_color bg)" \
      --unselected.background "$(__dnb_ui_backend_color selected)" \
      --unselected.foreground "$(__dnb_ui_backend_color fg)" \
      -- "${prompt}" >&2 || status=$?
    __dnb_ui_map_status "${status}"
    return
  fi

  printf '%s %s [y/N]: ' "$(dnb_ui_symbol prompt)" "${prompt}" >&2
  IFS= read -r answer || return 130
  case "${answer}" in
  [Yy] | [Yy][Ee][Ss]) return 0 ;;
  *) return 1 ;;
  esac
}

# __dnb_ui_parse_options CALLER ARRAY_NAME PROMPT_NAME ARGS...
#
# Parse --prompt and repeated --option arguments.
__dnb_ui_parse_options() {
  local caller="${1}"
  local -n __options_ref="${2}"
  local -n __prompt_ref="${3}"
  shift 3

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    --prompt) __prompt_ref="${2-}" && shift 2 || return 2 ;;
    --option)
      [[ "$#" -ge 2 ]] || return 2
      __dnb_ui_check_text "${caller}" "${2}" || return 2
      __options_ref+=("${2}")
      shift 2
      ;;
    *)
      printf '%s: unknown argument: %s\n' "${caller}" "${1}" >&2
      return 2
      ;;
    esac
  done
  __dnb_ui_check_text "${caller}" "${__prompt_ref}" || return 2
  if [[ "${#__options_ref[@]}" -eq 0 ]]; then
    printf '%s: at least one --option is required\n' "${caller}" >&2
    return 2
  fi
}

# __dnb_ui_numbered_menu PROMPT OPTIONS...
#
# Plain fallback: numbered menu on stderr, selected value on stdout.
__dnb_ui_numbered_menu() {
  local prompt="${1}"
  shift
  local options=("$@")
  local answer='' i=0

  [[ -n "${prompt}" ]] && printf '%s %s\n' "$(dnb_ui_symbol prompt)" "${prompt}" >&2
  for ((i = 0; i < ${#options[@]}; i++)); do
    printf '  %d) %s\n' "$((i + 1))" "${options[i]}" >&2
  done
  while true; do
    printf 'Number (empty to cancel): ' >&2
    IFS= read -r answer || return 130
    [[ -n "${answer}" ]] || return 130
    if [[ "${answer}" =~ ^[0-9]+$ ]] && ((answer >= 1 && answer <= ${#options[@]})); then
      printf '%s\n' "${options[answer - 1]}"
      return 0
    fi
    printf 'Enter a number from 1 to %d.\n' "${#options[@]}" >&2
  done
}

# dnb_ui_select --prompt TEXT --option VALUE [--option VALUE ...]
#
# Choose one value from a small fixed list. The value goes to stdout.
dnb_ui_select() {
  local prompt='' options=() selected='' status=0

  __dnb_ui_parse_options "${FUNCNAME[0]}" options prompt "$@" || return 2
  __dnb_ui_require_interactive "${FUNCNAME[0]}" || return

  if __dnb_ui_use_gum; then
    selected="$(gum choose \
      --header "${prompt}" \
      --header.foreground "$(__dnb_ui_backend_color accent)" \
      --cursor.foreground "$(__dnb_ui_backend_color cursor)" \
      --selected.foreground "$(__dnb_ui_backend_color accent)" \
      -- "${options[@]}")" || status=$?
    # Gum reports Esc as 1 or 130; neither is a "no".
    ((status == 1)) && status=130
    __dnb_ui_map_status "${status}" || return
    [[ -n "${selected}" ]] || return 130
    printf '%s\n' "${selected}"
    return 0
  fi

  __dnb_ui_numbered_menu "${prompt}" "${options[@]}"
}

# dnb_ui_filter --prompt TEXT --option VALUE [--option VALUE ...]
#
# Type-ahead choice from a small controlled list. The value goes to stdout.
dnb_ui_filter() {
  local prompt='' options=() selected='' status=0

  __dnb_ui_parse_options "${FUNCNAME[0]}" options prompt "$@" || return 2
  __dnb_ui_require_interactive "${FUNCNAME[0]}" || return

  if __dnb_ui_use_gum; then
    selected="$(gum filter \
      --header "${prompt}" \
      --header.foreground "$(__dnb_ui_backend_color accent)" \
      --indicator.foreground "$(__dnb_ui_backend_color cursor)" \
      --match.foreground "$(__dnb_ui_backend_color accent)" \
      --prompt.foreground "$(__dnb_ui_backend_color accent)" \
      -- "${options[@]}")" || status=$?
    ((status == 1)) && status=130
    __dnb_ui_map_status "${status}" || return
    [[ -n "${selected}" ]] || return 130
    printf '%s\n' "${selected}"
    return 0
  fi

  __dnb_ui_numbered_menu "${prompt}" "${options[@]}"
}

# dnb_ui_search --prompt TEXT --items-file PATH [--null]
#
# Fuzzy search over a large or dynamic record list with fzf. Records come
# from the file, never from stdin. --null reads and prints NUL-delimited
# records (for arbitrary filenames). The selected record goes to stdout.
# Returns 1 when nothing matched and 3 when fzf is not available.
dnb_ui_search() {
  local prompt='' items_file='' null_mode='false' status=0
  local fzf_args=()

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    --prompt) prompt="${2-}" && shift 2 || return 2 ;;
    --items-file) items_file="${2-}" && shift 2 || return 2 ;;
    --null)
      null_mode='true'
      shift
      ;;
    *)
      printf '%s: unknown argument: %s\n' "${FUNCNAME[0]}" "${1}" >&2
      return 2
      ;;
    esac
  done
  __dnb_ui_check_text "${FUNCNAME[0]}" "${prompt}" || return 2
  if [[ -z "${items_file}" || ! -r "${items_file}" ]]; then
    printf '%s: readable --items-file is required\n' "${FUNCNAME[0]}" >&2
    return 2
  fi
  __dnb_ui_require_interactive "${FUNCNAME[0]}" || return
  if [[ "$(dnb_ui_mode)" != 'auto' ]] || ! __dnb_ui_has fzf; then
    printf '%s: search is unavailable (fzf missing or plain mode); pass the value explicitly\n' "${FUNCNAME[0]}" >&2
    return 3
  fi

  fzf_args=(--prompt "${prompt:+${prompt} }> " --height '40%' --layout reverse --border none)
  if ! dnb_ui_supports_color --fd 2; then
    fzf_args+=(--no-color)
  elif [[ "$(__dnb_color_mode)" == 'truecolor' || "$(__dnb_color_mode)" == '256' ]]; then
    fzf_args+=(--color "fg:$(__dnb_ui_backend_color fg),hl:$(__dnb_ui_backend_color accent),fg+:$(__dnb_ui_backend_color fg),bg+:$(__dnb_ui_backend_color selected),hl+:$(__dnb_ui_backend_color accent),info:$(__dnb_ui_backend_color muted),prompt:$(__dnb_ui_backend_color accent),pointer:$(__dnb_ui_backend_color cursor),marker:$(__dnb_ui_backend_color success),spinner:$(__dnb_ui_backend_color accent_alt),header:$(__dnb_ui_backend_color muted),border:$(__dnb_ui_backend_color border)")
  fi
  [[ "${null_mode}" == 'true' ]] && fzf_args+=(--read0 --print0)

  fzf "${fzf_args[@]}" <"${items_file}" || status=$?
  __dnb_ui_map_status "${status}"
}

# dnb_ui_spin --title TEXT -- COMMAND [ARG ...]
#
# Run COMMAND once with progress on stderr. Child stdout and stderr keep
# their streams; the child's exit status is returned unchanged. Gum buffers
# child output until the command finishes and gives the child no stdin.
dnb_ui_spin() {
  local title=''

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    --title) title="${2-}" && shift 2 || return 2 ;;
    --)
      shift
      break
      ;;
    *)
      printf '%s: unknown argument: %s\n' "${FUNCNAME[0]}" "${1}" >&2
      return 2
      ;;
    esac
  done
  if [[ "$#" -eq 0 ]]; then
    printf '%s: a command is required after --\n' "${FUNCNAME[0]}" >&2
    return 2
  fi
  __dnb_ui_check_text "${FUNCNAME[0]}" "${title}" || return 2

  if __dnb_ui_quiet; then
    "$@"
    return
  fi
  if [[ -t 2 ]] && __dnb_ui_use_gum && dnb_ui_supports_color --fd 2; then
    gum spin \
      --title "${title}" \
      --spinner.foreground "$(__dnb_ui_backend_color accent)" \
      --title.foreground "$(__dnb_ui_backend_color fg)" \
      --show-stdout --show-stderr \
      -- "$@"
    return
  fi

  [[ -n "${title}" ]] && printf '%s %s\n' "$(dnb_ui_symbol action)" "${title}" >&2
  "$@"
}

# dnb_ui_table --input PATH [--stream stdout|stderr]
#
# Print a table from a tab-separated file; the first line is the header.
# Cells must not contain control characters. Results go to stdout by
# default; status tables use --stream stderr. Without a styled terminal the
# output is a stable, space-aligned plain table.
dnb_ui_table() {
  local input='' stream='stdout' fd=1
  local line='' header='true'
  local -a widths=() cells=()
  local i=0 row=''

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
    --input) input="${2-}" && shift 2 || return 2 ;;
    --stream) stream="${2-}" && shift 2 || return 2 ;;
    *)
      printf '%s: unknown argument: %s\n' "${FUNCNAME[0]}" "${1}" >&2
      return 2
      ;;
    esac
  done
  case "${stream}" in
  stdout) fd=1 ;;
  stderr) fd=2 ;;
  *)
    printf '%s: --stream must be stdout or stderr\n' "${FUNCNAME[0]}" >&2
    return 2
    ;;
  esac
  if [[ -z "${input}" || ! -r "${input}" ]]; then
    printf '%s: readable --input is required\n' "${FUNCNAME[0]}" >&2
    return 2
  fi
  while IFS= read -r line || [[ -n "${line}" ]]; do
    __dnb_ui_check_text "${FUNCNAME[0]}" "${line//$'\t'/ }" || return 2
  done <"${input}"

  if dnb_ui_supports_color --fd "${fd}" && __dnb_ui_unicode && __dnb_ui_has gum; then
    gum table --print --separator $'\t' --file "${input}" \
      --border rounded \
      --border.foreground "$(__dnb_ui_backend_color border)" \
      --header.foreground "$(__dnb_ui_backend_color accent)" \
      --cell.foreground "$(__dnb_ui_backend_color fg)" >&"${fd}"
    return
  fi

  while IFS= read -r line || [[ -n "${line}" ]]; do
    IFS=$'\t' read -r -a cells <<<"${line}"
    for ((i = 0; i < ${#cells[@]}; i++)); do
      ((${#cells[i]} > ${widths[i]:-0})) && widths[i]="${#cells[i]}"
    done
  done <"${input}"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    IFS=$'\t' read -r -a cells <<<"${line}"
    row=''
    for ((i = 0; i < ${#widths[@]}; i++)); do
      printf -v row '%s%-*s  ' "${row}" "${widths[i]}" "${cells[i]:-}"
    done
    printf '%s\n' "${row%"${row##*[! ]}"}" >&"${fd}"
    if [[ "${header}" == 'true' ]]; then
      header='false'
      row=''
      for ((i = 0; i < ${#widths[@]}; i++)); do
        printf -v line '%*s' "${widths[i]}" ''
        row+="${line// /-}  "
      done
      printf '%s\n' "${row%  }" >&"${fd}"
    fi
  done <"${input}"
}

# __dnb_ui_render_check CALLER FILE
#
# Validate a document path argument.
__dnb_ui_render_check() {
  if [[ -z "${2}" || ! -r "${2}" ]]; then
    printf '%s: readable --file is required\n' "${1}" >&2
    return 2
  fi
}

# __dnb_ui_file_arg CALLER ARGS...
#
# Parse `--file PATH` and print PATH.
__dnb_ui_file_arg() {
  local caller="${1}"
  shift
  if [[ "${1:-}" != '--file' || "$#" -ne 2 ]]; then
    printf '%s: usage: %s --file PATH\n' "${caller}" "${caller}" >&2
    return 2
  fi
  printf '%s\n' "${2}"
}

# dnb_ui_markdown --file PATH
#
# Print a Markdown document on stdout, rendered with Glow on a colour
# terminal, otherwise unchanged. Never pages.
dnb_ui_markdown() {
  local file='' style=''

  file="$(__dnb_ui_file_arg "${FUNCNAME[0]}" "$@")" || return 2
  __dnb_ui_render_check "${FUNCNAME[0]}" "${file}" || return 2

  if dnb_ui_supports_color --fd 1 && __dnb_ui_has glow; then
    style="$(__dnb_ui_lib_root)/configs/theme/dnb-terminal/glow/$(__dnb_ui_theme_name).json"
    [[ -r "${style}" ]] || style='dark'
    glow --style "${style}" --width "$(__dnb_ui_width)" -- "${file}" && return 0
    dnb_ui_warning 'Glow failed; showing the plain document.'
  fi
  cat -- "${file}"
}

# __dnb_ui_bat_theme [BAT_COMMAND]
#
# Print the bat theme for the active DNB theme, or `ansi` when the derived
# theme is not in bat's cache. delta reads the same cache.
__dnb_ui_bat_theme() {
  local bat_cmd="${1:-bat}"
  local name='DNB Dracula Pro'

  [[ "$(__dnb_ui_theme_name)" == 'dracula-pro-dark' ]] && name='DNB Dracula Pro Dark'
  if "${bat_cmd}" --list-themes --color=never 2>/dev/null | grep -qxF -- "${name}"; then
    printf '%s\n' "${name}"
  else
    printf 'ansi\n'
  fi
}

# dnb_ui_code --file PATH
#
# Print a source or configuration file on stdout, highlighted with bat on a
# colour terminal, otherwise unchanged. Never pages.
dnb_ui_code() {
  local file='' bat_cmd='bat'

  file="$(__dnb_ui_file_arg "${FUNCNAME[0]}" "$@")" || return 2
  __dnb_ui_render_check "${FUNCNAME[0]}" "${file}" || return 2

  __dnb_ui_has bat || bat_cmd='batcat'
  if dnb_ui_supports_color --fd 1 && __dnb_ui_has "${bat_cmd}"; then
    "${bat_cmd}" --paging=never --color=always --style=numbers,header \
      --theme "$(__dnb_ui_bat_theme "${bat_cmd}")" -- "${file}" && return 0
    dnb_ui_warning 'bat failed; showing the plain file.'
  fi
  cat -- "${file}"
}

# dnb_ui_diff --file PATH
#
# Print a unified diff on stdout, rendered with delta on a colour terminal,
# otherwise unchanged. Never pages. Ignores the user's gitconfig delta
# features so the theme tokens apply.
dnb_ui_diff() {
  local file=''

  file="$(__dnb_ui_file_arg "${FUNCNAME[0]}" "$@")" || return 2
  __dnb_ui_render_check "${FUNCNAME[0]}" "${file}" || return 2

  if dnb_ui_supports_color --fd 1 && __dnb_ui_has delta; then
    delta --no-gitconfig --paging=never \
      --syntax-theme "$(__dnb_ui_bat_theme)" \
      --minus-style "$(__dnb_ui_backend_color error)" \
      --minus-emph-style "bold $(__dnb_ui_backend_color error)" \
      --plus-style "$(__dnb_ui_backend_color success)" \
      --plus-emph-style "bold $(__dnb_ui_backend_color success)" \
      --file-style "$(__dnb_ui_backend_color accent)" \
      --file-decoration-style "$(__dnb_ui_backend_color border) ul" \
      --hunk-header-style "file line-number $(__dnb_ui_backend_color muted)" \
      --hunk-header-decoration-style "$(__dnb_ui_backend_color border) box" \
      <"${file}" && return 0
    dnb_ui_warning 'delta failed; showing the plain diff.'
  fi
  cat -- "${file}"
}
