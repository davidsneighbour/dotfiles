#!/bin/bash

set -Eeuo pipefail

###############################################################################
# git-sync.sh
# Clone a repository if missing, otherwise update it to the latest of a branch.
#
# Supports:
#   git-sync <repo> <dir> [options]
#   git-sync --repo <url> --dir <path> [options]
#
# Explicit flags override positional args.
###############################################################################

print_help() {
  local cmd
  cmd="$(basename "$0")"

  cat <<EOF
Usage:
  ${cmd} <repo> <dir> [options]
  ${cmd} --repo <url> --dir <path> [options]

Positional:
  <repo>               Repository URL
  <dir>                Target directory

Options:
  --repo <url>         Repository URL (overrides positional)
  --dir <path>         Target directory (overrides positional)
  --branch <name>      Branch to use (default: main; auto-detect remote default if main not present and --branch not set)
  --force              Hard reset to origin/<branch> (destroys local changes)
  --rebase             Rebase local branch onto origin/<branch> (linear history, no merge commits)
  --depth <n>          Shallow clone/fetch depth (0 = full, default: 0)
  --dry-run            Print commands, do not execute
  --verbose            Verbose output
  --help               Show help

Examples:
  ${cmd} git@github.com:user/repo.git repo
  ${cmd} git@github.com:user/repo.git repo --branch develop
  ${cmd} --repo https://github.com/user/repo.git --dir repo --rebase
  ${cmd} repoUrl repoDir --force --dry-run
EOF
}

###############################################################################
# Defaults
###############################################################################

BRANCH="main"
BRANCH_WAS_SET="false"
FORCE="false"
REBASE="false"
DEPTH="0"
DRY_RUN="false"
VERBOSE="false"

REPO_URL=""
TARGET_DIR=""

POS_REPO=""
POS_DIR=""

###############################################################################
# Helpers
###############################################################################

log() {
  if [[ "${VERBOSE}" == "true" ]]; then
    echo "[git-sync] $*"
  fi
}

die() {
  echo "Error: $*" >&2
  echo >&2
  print_help >&2
  exit 1
}

run() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

is_positive_int() {
  [[ "${1}" =~ ^[0-9]+$ ]]
}

# Try to resolve remote default branch via ls-remote symref HEAD.
# Prints branch name (without refs/heads/) on success, empty on failure.
get_remote_default_branch() {
  local url="$1"
  local out ref
  out="$(git ls-remote --symref "${url}" HEAD 2>/dev/null || true)"
  ref="$(printf '%s\n' "${out}" | awk '/^ref:/ {print $2; exit}')"
  if [[ -n "${ref}" ]]; then
    echo "${ref#refs/heads/}"
  else
    echo ""
  fi
}

# Checks if a remote branch exists.
remote_branch_exists() {
  local url="$1"
  local branch="$2"
  git ls-remote --exit-code --heads "${url}" "${branch}" >/dev/null 2>&1
}

###############################################################################
# Argument parsing
###############################################################################

if [[ $# -eq 0 ]]; then
  print_help
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
  --repo)
    REPO_URL="${2:-}"
    shift 2
    ;;
  --dir)
    TARGET_DIR="${2:-}"
    shift 2
    ;;
  --branch)
    BRANCH="${2:-}"
    BRANCH_WAS_SET="true"
    shift 2
    ;;
  --force)
    FORCE="true"
    shift
    ;;
  --rebase)
    REBASE="true"
    shift
    ;;
  --depth)
    DEPTH="${2:-}"
    shift 2
    ;;
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  --verbose)
    VERBOSE="true"
    shift
    ;;
  --help)
    print_help
    exit 0
    ;;
  --*)
    die "Unknown option: $1"
    ;;
  *)
    if [[ -z "${POS_REPO}" ]]; then
      POS_REPO="$1"
    elif [[ -z "${POS_DIR}" ]]; then
      POS_DIR="$1"
    else
      die "Unexpected extra positional argument: $1"
    fi
    shift
    ;;
  esac
done

###############################################################################
# Merge positional + explicit (explicit wins)
###############################################################################

if [[ -z "${REPO_URL}" && -n "${POS_REPO}" ]]; then
  REPO_URL="${POS_REPO}"
fi

if [[ -z "${TARGET_DIR}" && -n "${POS_DIR}" ]]; then
  TARGET_DIR="${POS_DIR}"
fi

###############################################################################
# Validation
###############################################################################

[[ -z "${REPO_URL}" ]] && die "Repository URL missing"
[[ -z "${TARGET_DIR}" ]] && die "Target directory missing"

is_positive_int "${DEPTH}" || die "--depth must be a non-negative integer"
# DEPTH=0 means full clone/fetch.

###############################################################################
# Branch auto-detection (only if --branch not provided)
###############################################################################

if [[ "${BRANCH_WAS_SET}" == "false" ]]; then
  # If main doesn't exist, try remote default branch.
  if ! remote_branch_exists "${REPO_URL}" "${BRANCH}"; then
    log "Branch '${BRANCH}' not found on remote. Trying to auto-detect remote default branch."
    detected="$(get_remote_default_branch "${REPO_URL}")"
    if [[ -n "${detected}" ]]; then
      BRANCH="${detected}"
      log "Detected remote default branch: ${BRANCH}"
    else
      log "Could not detect remote default branch. Keeping '${BRANCH}'."
    fi
  fi
fi

###############################################################################
# Main logic
###############################################################################

if [[ -d "${TARGET_DIR}/.git" ]]; then
  log "Repository exists. Updating ${TARGET_DIR} (branch: ${BRANCH})"

  # Determine origin URL for existing repo; keep REPO_URL only for branch checks.
  origin_url="$(git -C "${TARGET_DIR}" remote get-url origin 2>/dev/null || true)"
  if [[ -n "${origin_url}" ]]; then
    REPO_URL="${origin_url}"
  fi

  fetch_args=(git -C "${TARGET_DIR}" fetch origin "${BRANCH}")
  if [[ "${DEPTH}" != "0" && -f "${TARGET_DIR}/.git/shallow" ]]; then
    fetch_args=(git -C "${TARGET_DIR}" fetch --depth "${DEPTH}" origin "${BRANCH}")
  fi

  run "${fetch_args[@]}"
  run git -C "${TARGET_DIR}" checkout "${BRANCH}"

  if [[ "${FORCE}" == "true" ]]; then
    log "Force mode enabled. Hard reset to origin/${BRANCH}"
    run git -C "${TARGET_DIR}" reset --hard "origin/${BRANCH}"
  else
    if [[ "${REBASE}" == "true" ]]; then
      log "Rebase mode enabled. Rebasing onto origin/${BRANCH}"
      run git -C "${TARGET_DIR}" rebase "origin/${BRANCH}"
    else
      run git -C "${TARGET_DIR}" merge --ff-only "origin/${BRANCH}"
    fi
  fi
else
  log "Cloning into ${TARGET_DIR} (branch: ${BRANCH})"

  clone_args=(git clone --branch "${BRANCH}" --single-branch)
  if [[ "${DEPTH}" != "0" ]]; then
    clone_args+=(--depth "${DEPTH}")
  fi
  clone_args+=("${REPO_URL}" "${TARGET_DIR}")

  run "${clone_args[@]}"
fi

log "Done."
