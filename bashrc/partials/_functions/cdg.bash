#!/bin/bash
# shellcheck shell=bash
# dnb-dotfiles 3003.2.0


# cdg
#
# Select a GitHub repository with the gum-backed helper command and change the
# current interactive shell into the selected repository directory.
cdg() {
  local helper_path="${BASHRC_PATH:-${HOME}/.dotfiles/bashrc}/helpers/gh/cdg"
  local target_path=''
  local cd_command=''
  local arg=''
  local print_cd_command='false'

  if [[ "${1:-}" == '--help' ]]; then
    "${helper_path}" --help
    return $?
  fi

  if [[ ! -x "${helper_path}" ]]; then
    printf 'ERROR: cdg helper is missing or not executable: %s\n' "${helper_path}" >&2
    return 1
  fi

  for arg in "$@"; do
    if [[ "${arg}" == '--print-cd-command' ]]; then
      print_cd_command='true'
    fi
  done

  if [[ "${print_cd_command}" == 'true' ]]; then
    if ! cd_command="$("${helper_path}" "$@")"; then
      return 1
    fi

    eval "${cd_command}"
    return $?
  fi

  if ! target_path="$("${helper_path}" "$@")"; then
    return 1
  fi

  if [[ -z "${target_path}" ]]; then
    printf 'ERROR: cdg helper returned an empty path.\n' >&2
    return 1
  fi

  builtin cd "${target_path}" || return 1
}
