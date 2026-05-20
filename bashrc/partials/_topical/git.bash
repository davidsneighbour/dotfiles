#!/bin/bash
# shellcheck shell=bash

_git_each_direct_child_repo() {
  local git_marker
  local repo_path

  while IFS= read -r -d '' git_marker; do
    repo_path="$(dirname "${git_marker}")"

    if git -C "${repo_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf '%s\n' "${repo_path}"
    fi
  done < <(
    find . \
      -mindepth 2 \
      -maxdepth 2 \
      -name .git \
      \( -type d -o -type f \) \
      -print0
  )
}

git_list_all_subdir_stashes() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
Usage:
  ${FUNCNAME[0]}

Shows direct child repositories below the current folder that have at least one Git stash.
EOF
    return 0
  fi

  local repo_path
  local stash_list

  while IFS= read -r repo_path; do
    stash_list="$(git -C "${repo_path}" stash list 2>/dev/null || true)"

    if [[ -n "${stash_list}" ]]; then
      printf '%s\n' "${repo_path}"
    fi
  done < <(_git_each_direct_child_repo)
}

git_list_all_subdir_stashes_details() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
Usage:
  ${FUNCNAME[0]}

Shows direct child repositories below the current folder that have Git stashes,
followed by their full 'git stash list' output.
EOF
    return 0
  fi

  local repo_path
  local stash_list

  while IFS= read -r repo_path; do
    stash_list="$(git -C "${repo_path}" stash list 2>/dev/null || true)"

    if [[ -n "${stash_list}" ]]; then
      printf '%s\n' "${repo_path}"
      printf '%s\n' "${stash_list}" | sed 's/^/  /'
      printf '\n'
    fi
  done < <(_git_each_direct_child_repo)
}

git_list_all_subdir_unclean() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
Usage:
  ${FUNCNAME[0]}

Shows direct child repositories below the current folder with an unclean Git status.

A repository is considered unclean if 'git status --porcelain' returns output.
EOF
    return 0
  fi

  local repo_path
  local status_output

  while IFS= read -r repo_path; do
    status_output="$(git -C "${repo_path}" status --porcelain=v1 --untracked-files=all 2>/dev/null || true)"

    if [[ -n "${status_output}" ]]; then
      printf '%s\n' "${repo_path}"
    fi
  done < <(_git_each_direct_child_repo)
}

git_list_all_subdir_unclean_details() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
Usage:
  ${FUNCNAME[0]}

Shows direct child repositories below the current folder with an unclean Git status,
followed by detailed short status output.
EOF
    return 0
  fi

  local repo_path
  local status_output
  local branch_output

  while IFS= read -r repo_path; do
    status_output="$(git -C "${repo_path}" status --porcelain=v1 --untracked-files=all 2>/dev/null || true)"

    if [[ -n "${status_output}" ]]; then
      branch_output="$(git -C "${repo_path}" status --short --branch --untracked-files=all 2>/dev/null || true)"

      printf '%s\n' "${repo_path}"
      printf '%s\n' "${branch_output}" | sed 's/^/  /'
      printf '\n'
    fi
  done < <(_git_each_direct_child_repo)
}

# Aliases without function equivalent
alias gits='git status --ignore-submodules --long --show-stash --ahead-behind --column'
alias gitst='git status --short | grep '^[AMDRC]''

# Aliases from functions above
alias git-list-all-subdir-stashes='git_list_all_subdir_stashes'
alias git-list-all-subdir-stashes-details='git_list_all_subdir_stashes_details'
alias git-list-all-subdir-unclean='git_list_all_subdir_unclean'
alias git-list-all-subdir-unclean-details='git_list_all_subdir_unclean_details'
