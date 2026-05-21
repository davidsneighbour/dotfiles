#!/bin/bash

# Git marker helper for interactive shells.
# No global shell options are set here because this file is intended to be sourced
# from .bashrc or another interactive shell loader.

# shellcheck shell=bash

##
# Print help for the git marker dispatcher.
#
# Behaviour:
# - Shows available commands and examples.
# - Uses ${FUNCNAME[0]} so the displayed function name stays correct.
#
# Examples:
#   dnb_git_marker_help
##
dnb_git_marker_help() {
  local command_name="${FUNCNAME[1]:-dnb_git_marker}"

  cat <<EOF
Usage:
  ${command_name} set [ref]
  ${command_name} diff [git-diff-options]
  ${command_name} show
  ${command_name} clear
  ${command_name} help

Commands:
  set      Save the current repository HEAD hash, or the hash of [ref].
  diff     Show the difference between the saved marker and the current working tree.
  show     Show the currently saved marker for this repository.
  clear    Remove the saved marker for this repository.
  help     Show this help.

Examples:
  ${command_name} set
  ${command_name} set HEAD~3
  ${command_name} diff
  ${command_name} diff --stat
  ${command_name} diff --name-only
  ${command_name} clear

Aliases:
  gitmark-set
  gitmark-diff
  gitmark-show
  gitmark-clear

Storage:
  \${DOTFILES_PATH:-\${HOME}/.dotfiles}/.cache/git-markers/
EOF
}

##
# Return the dotfiles cache directory for git markers.
#
# Output:
# - Prints the cache directory path.
#
# Behaviour:
# - Uses DOTFILES_PATH when available.
# - Falls back to ${HOME}/.dotfiles.
#
# Examples:
#   marker_cache_dir="$(dnb_git_marker_cache_dir)"
##
dnb_git_marker_cache_dir() {
  local dotfiles_path="${DOTFILES_PATH:-${HOME}/.dotfiles}"

  printf '%s\n' "${dotfiles_path}/cache/git-markers"
}

##
# Return the current Git repository root.
#
# Output:
# - Prints the absolute repository root path.
#
# Returns:
# - 0 if inside a Git repository.
# - 1 otherwise.
#
# Examples:
#   repo_root="$(dnb_git_marker_repo_root)"
##
dnb_git_marker_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

##
# Return a stable marker file path for the current Git repository.
#
# Output:
# - Prints the marker file path.
#
# Behaviour:
# - Creates one marker file per repository root.
# - Uses sha256sum when available.
# - Falls back to cksum if sha256sum is unavailable.
#
# Examples:
#   marker_file="$(dnb_git_marker_file)"
##
dnb_git_marker_file() {
  local repo_root
  local cache_dir
  local repo_id
  local repo_name

  repo_root="$(dnb_git_marker_repo_root)" || {
    printf 'Error: not inside a Git repository.\n' >&2
    return 1
  }

  cache_dir="$(dnb_git_marker_cache_dir)"
  repo_name="$(basename "${repo_root}")"

  if command -v sha256sum >/dev/null 2>&1; then
    repo_id="$(printf '%s' "${repo_root}" | sha256sum | awk '{print $1}')"
  else
    repo_id="$(printf '%s' "${repo_root}" | cksum | awk '{print $1}')"
  fi

  printf '%s/%s-%s.marker\n' "${cache_dir}" "${repo_name}" "${repo_id}"
}

##
# Save a Git commit hash as marker for the current repository.
#
# Parameters:
# - $1 optional Git ref. Defaults to HEAD.
#
# Behaviour:
# - Resolves the ref to a commit hash.
# - Stores the hash in DOTFILES_PATH/.cache/git-markers/.
# - Stores one marker per repository path.
#
# Examples:
#   dnb_git_marker_set
#   dnb_git_marker_set HEAD~3
#   dnb_git_marker_set main
##
dnb_git_marker_set() {
  local ref="${1:-HEAD}"
  local marker_file
  local cache_dir
  local commit_hash
  local repo_root

  repo_root="$(dnb_git_marker_repo_root)" || {
    printf 'Error: not inside a Git repository.\n' >&2
    return 1
  }

  commit_hash="$(git rev-parse --verify "${ref}^{commit}" 2>/dev/null)" || {
    printf 'Error: Git ref "%s" does not resolve to a commit.\n' "${ref}" >&2
    return 1
  }

  marker_file="$(dnb_git_marker_file)" || return 1
  cache_dir="$(dirname "${marker_file}")"

  mkdir -p "${cache_dir}" || {
    printf 'Error: could not create cache directory: %s\n' "${cache_dir}" >&2
    return 1
  }

  {
    printf 'repo=%s\n' "${repo_root}"
    printf 'hash=%s\n' "${commit_hash}"
    printf 'ref=%s\n' "${ref}"
    printf 'created=%s\n' "$(date --iso-8601=seconds)"
  } >"${marker_file}" || {
    printf 'Error: could not write marker file: %s\n' "${marker_file}" >&2
    return 1
  }

  printf 'Git marker set: %s\n' "${commit_hash}"
}

##
# Read the saved Git marker hash for the current repository.
#
# Output:
# - Prints the saved commit hash.
#
# Returns:
# - 0 if a marker exists and contains a hash.
# - 1 otherwise.
#
# Examples:
#   marker_hash="$(dnb_git_marker_hash)"
##
dnb_git_marker_hash() {
  local marker_file
  local marker_hash

  marker_file="$(dnb_git_marker_file)" || return 1

  if [[ ! -f "${marker_file}" ]]; then
    printf 'Error: no Git marker set for this repository.\n' >&2
    printf 'Run: gitmark-set\n' >&2
    return 1
  fi

  marker_hash="$(awk -F '=' '$1 == "hash" {print $2}' "${marker_file}")"

  if [[ -z "${marker_hash}" ]]; then
    printf 'Error: marker file does not contain a hash: %s\n' "${marker_file}" >&2
    return 1
  fi

  printf '%s\n' "${marker_hash}"
}

##
# Show the saved Git marker for the current repository.
#
# Behaviour:
# - Prints repository path, saved hash, original ref, and created timestamp.
#
# Examples:
#   dnb_git_marker_show
##
dnb_git_marker_show() {
  local marker_file

  marker_file="$(dnb_git_marker_file)" || return 1

  if [[ ! -f "${marker_file}" ]]; then
    printf 'No Git marker set for this repository.\n'
    return 1
  fi

  cat "${marker_file}"
}

##
# Show differences between the saved marker and the current working tree.
#
# Parameters:
# - Git diff options may be passed before --.
# - Optional pathspecs may be passed after --.
#
# Behaviour:
# - Compares the current working tree against the saved marker commit.
# - Includes committed, staged, and unstaged tracked-file changes.
# - Does not include untracked files, because Git cannot diff them against a commit.
#
# Examples:
#   dnb_git_marker_diff
#   dnb_git_marker_diff --stat
#   dnb_git_marker_diff --name-only
#   dnb_git_marker_diff -- src/
#   dnb_git_marker_diff --stat -- src/
##
dnb_git_marker_diff() {
  local marker_hash
  local untracked_count
  local arg
  local seen_separator="false"
  local -a diff_args=()
  local -a pathspecs=()

  marker_hash="$(dnb_git_marker_hash)" || return 1

  if ! git cat-file -e "${marker_hash}^{commit}" 2>/dev/null; then
    printf 'Error: saved marker no longer exists in this repository: %s\n' "${marker_hash}" >&2
    return 1
  fi

  untracked_count="$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')"

  if [[ "${untracked_count}" != "0" ]]; then
    printf 'Note: %s untracked file(s) are not included in git diff output.\n\n' "${untracked_count}" >&2
  fi

  for arg in "$@"; do
    if [[ "${arg}" == "--" && "${seen_separator}" == "false" ]]; then
      seen_separator="true"
      continue
    fi

    if [[ "${seen_separator}" == "true" ]]; then
      pathspecs+=("${arg}")
    else
      diff_args+=("${arg}")
    fi
  done

  git diff "${diff_args[@]}" "${marker_hash}" -- "${pathspecs[@]}"
}

##
# Clear the saved Git marker for the current repository.
#
# Behaviour:
# - Removes the marker file for the current repository.
#
# Examples:
#   dnb_git_marker_clear
##
dnb_git_marker_clear() {
  local marker_file

  marker_file="$(dnb_git_marker_file)" || return 1

  if [[ ! -f "${marker_file}" ]]; then
    printf 'No Git marker set for this repository.\n'
    return 0
  fi

  rm -f "${marker_file}" || {
    printf 'Error: could not remove marker file: %s\n' "${marker_file}" >&2
    return 1
  }

  printf 'Git marker cleared.\n'
}

##
# Dispatch Git marker commands.
#
# Parameters:
# - $1 command: set, diff, show, clear, help.
# - Remaining parameters are passed to the selected command.
#
# Behaviour:
# - Prints help when no command is provided.
# - Fails with an error for unknown commands.
#
# Examples:
#   dnb_git_marker set
#   dnb_git_marker diff --stat
#   dnb_git_marker clear
##
dnb_git_marker() {
  local command="${1:-help}"

  if [[ $# -gt 0 ]]; then
    shift
  fi

  case "${command}" in
  set)
    dnb_git_marker_set "$@"
    ;;
  diff)
    dnb_git_marker_diff "$@"
    ;;
  show)
    dnb_git_marker_show "$@"
    ;;
  clear)
    dnb_git_marker_clear "$@"
    ;;
  help | --help | -h)
    dnb_git_marker_help
    ;;
  *)
    printf 'Error: unknown git marker command: %s\n\n' "${command}" >&2
    dnb_git_marker_help
    return 1
    ;;
  esac
}

alias gitmark='dnb_git_marker'
alias gitmark-set='dnb_git_marker_set'
alias gitmark-diff='dnb_git_marker_diff'
alias gitmark-show='dnb_git_marker_show'
alias gitmark-clear='dnb_git_marker_clear'
