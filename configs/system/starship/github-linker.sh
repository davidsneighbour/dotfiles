#!/bin/bash
# Clickable GitHub path links via OSC 8.
# Works with folders like: ~/github.com/<user>/<repo>[/*...]

# see https://chatgpt.com/share/68994427-dc64-8009-bd4c-d5011b0a170b

_osc8_link() {
  if [ "${1-}" = "--help" ]; then
    cat <<'EOF'
Usage: _osc8_link <url> <label>
Create a terminal hyperlink with OSC 8.
EOF
    return 0
  fi
  local url="${1-}" label="${2-}"
  if [ -z "${url}" ] || [ -z "${label}" ]; then
    printf 'Error: url and label required\n' >&2
    return 2
  fi
  printf '\e]8;;%s\a%s\e]8;;\a' "${url}" "${label}"
}

# Return the subpath after */github.com/, or empty if not matched.

_gh_after_root() {
  # Succeeds if PATH contains /github.com or /github.com/
  # Prints the subpath after github.com/, or empty at the root.
  local path="${1-}"
  [ -z "${path}" ] && return 2

  # Match both ".../github.com" and ".../github.com/..."
  case "${path}" in
    */github.com|*/github.com/*) : ;;
    *) return 1 ;;
  esac

  # Strip up to /github.com and an optional following slash
  local rest="${path#*/github.com}"
  rest="${rest#/}"   # remove a single leading slash if present
  printf '%s' "${rest}"
  return 0
}

# Print clickable link(s) for the current path depth under github.com:
# - depth 0: github.com
# - depth 1: github.com/user
# - depth 2+: github.com/user/repo
_gh_prompt_links() {
  local rest; rest="$(_gh_after_root "${PWD}")" || return 0
  local root='https://github.com'

  # Split into segments without external tools
  local seg1 seg2
  seg1="${rest%%/*}"               # first segment (possibly whole)
  seg2="${rest#*/}"; [ "${seg2}" = "${rest}" ] && seg2=''   # second+ or empty
  seg2="${seg2%%/*}"               # keep only second

  if [ -z "${rest}" ] || [ "${rest}" = "${PWD}" ]; then
    # somehow failed; show root only
    _osc8_link "${root}" "github.com"
    return 0
  fi

  if [ -z "${seg1}" ]; then
    _osc8_link "${root}" "github.com"
    return 0
  fi

  if [ -z "${seg2}" ]; then
    # depth 1: user only
    _osc8_link "${root}" "github.com"
    printf '/'
    _osc8_link "${root}/${seg1}" "${seg1}"
    return 0
  fi

  # depth 2+: user/repo
  _osc8_link "${root}" "github.com"
  printf '/'
  _osc8_link "${root}/${seg1}" "${seg1}"
  printf '/'
  _osc8_link "${root}/${seg1}/${seg2}" "${seg2}"
}

# CLI helper for ad-hoc printing (optional)
gh-links() {
  if [ "${1-}" = "--help" ]; then
    cat <<'EOF'
Usage: gh-links
Print clickable github.com(/user)(/repo) for $PWD if inside */github.com/*.
EOF
    return 0
  fi
  _gh_prompt_links
  printf '\n'
}
