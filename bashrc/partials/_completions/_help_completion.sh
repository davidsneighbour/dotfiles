# shellcheck shell=bash
# Session-local data only: never source or evaluate help output.
declare -gA _dnb_help_data _dnb_help_stamp _dnb_help_time

dnb_register_completion() {
  [[ $# == 1 && $1 =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]] || return 2
  complete -o default -F _dnb_help_complete -- "${1}"
}

# Clear all metadata, including cached failures. Registration remains intact.
dnb_completion_refresh() {
  _dnb_help_data=()
  _dnb_help_stamp=()
  _dnb_help_time=()
}

_dnb_help_parse() {
  LC_ALL=C awk '
    /^Options:$/ { section="options"; next }
    /^Commands:$/ { section="commands"; next }
    /^[^ ]/ { section="" }
    section == "options" && /^  / {
      line=$0; sub(/^ +/, "", line); sub(/  +.*/, "", line)
      value=(line ~ /<[^>]+>/ ? "value" : "flag")
      gsub(/,/, " ", line); n=split(line, words, / +/)
      for (i=1;i<=n;i++)
        if (words[i] ~ /^--[a-zA-Z0-9][a-zA-Z0-9-]*$/ || words[i] ~ /^-[a-zA-Z0-9]$/)
          print "option", words[i], value
    }
    section == "commands" && /^  [a-zA-Z0-9]/ {
      if ($1 ~ /^[a-zA-Z0-9][a-zA-Z0-9_-]*$/) print "command", $1, "flag"
    }'
}

# Set a caller-local metadata variable; do not use command substitution here,
# because it would discard updates to the session cache.
_dnb_help_metadata() {
  local command="${1}" key stamp path help
  shift
  key="${command} ${*}"
  if declare -F -- "${command}" >/dev/null; then
    stamp=$(declare -f -- "${command}" | cksum)
  else
    path=$(type -P -- "${command}") || return 1
    stamp="${path}:$(stat -Lc '%y:%s:%i' -- "${path}")" || return 1
  fi
  if [[ ${_dnb_help_stamp[${key}]-} != "${stamp}" ]] ||
    ((SECONDS - ${_dnb_help_time[${key}]:--300} >= 300)); then
    # A subshell protects the interactive shell from help functions that change
    # directory, variables, or shell options. Only explicitly registered tools run.
    if help=$( (
      export NO_COLOR=1 TERM=dumb
      "${command}" "${@}" --help
    ) 2>/dev/null); then
      _dnb_help_data[${key}]=$(printf '%s\n' "${help}" | _dnb_help_parse)
    else
      # Cache failures too, avoiding repeated failed startup on every Tab.
      _dnb_help_data[${key}]=''
    fi
    _dnb_help_stamp[${key}]="${stamp}"
    _dnb_help_time[${key}]=${SECONDS}
  fi
  metadata="${_dnb_help_data[${key}]}"
}

_dnb_help_complete() {
  local command="${COMP_WORDS[0]}" current="${COMP_WORDS[COMP_CWORD]}"
  local metadata='' kind name mode word pending=0 stopped=0 i
  local -a context=()
  COMPREPLY=()
  _dnb_help_metadata "${command}" || return 0
  for ((i = 1; i < COMP_CWORD; i++)); do
    word="${COMP_WORDS[i]}"
    if ((pending)); then
      pending=0
      continue
    fi
    if [[ ${word} == -- ]]; then
      stopped=1
      break
    fi
    while read -r kind name mode; do
      if [[ ${word} == "${name}" ]]; then
        if [[ ${kind} == option && ${mode} == value ]]; then
          pending=1
        elif [[ ${kind} == command ]]; then
          context+=("${word}")
          _dnb_help_metadata "${command}" "${context[@]}" || return 0
          break
        fi
      fi
    done <<<"${metadata}"
  done
  ((pending || stopped)) && return 0
  while read -r kind name mode; do
    [[ -n ${name} && ${name} == "${current}"* ]] && COMPREPLY+=("${name}")
  done <<<"${metadata}"
  return 0
}
