#!/bin/bash
# shellcheck disable=SC2317

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
LOG_DIR="${HOME}/.logs/github"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
LOG_FILE="${LOG_DIR}/label-migration-${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

usage() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} [--repo OWNER/REPO ...] [--apply] [--clear] [--verbose]

Description:
  Create or update the default GitHub label taxonomy for one or more repositories.

Default behaviour:
  * Runs in DRY-RUN mode (no changes applied).
  * If no --repo is provided, the script tries to detect the current GitHub repository
    from the local git checkout.

Authentication:
  * If GITHUB_TOKEN_CONTENT_PRIVATE is set, it is exported as GH_TOKEN for this script.
  * Otherwise gh falls back to GH_TOKEN, GITHUB_TOKEN, or stored gh authentication.

Options:
  --repo OWNER/REPO   Repository to update. Can be provided multiple times.
                       If omitted, the current repository is detected automatically.
  --apply             Apply changes (disable dry-run).
  --clear             Remove all existing labels before applying the default taxonomy.
  --verbose           Print detailed progress output.
  --help              Show this help message.

Behaviour:
  * Default is dry-run for safety.
  * --clear is only executed when combined with --apply (otherwise shown as dry-run output).
  * Uses 'gh label create --force' so exact-name matches are updated in place.
  * Does not rename or delete legacy labels with different names.
  * Label names are matched by exact label name semantics on GitHub.
  * Explicit --repo values override automatic current-repo detection.

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --apply
  ${SCRIPT_NAME} --apply --clear
  ${SCRIPT_NAME} --repo davidsneighbour/dotfiles
  ${SCRIPT_NAME} --repo davidsneighbour/dotfiles --apply
  ${SCRIPT_NAME} --repo davidsneighbour/dotfiles --apply --clear
  ${SCRIPT_NAME} --repo davidsneighbour/dotfiles --repo davidsneighbour/kollitsch.dev --apply --verbose
EOF
}

log() {
  local level="$1"
  shift
  local message="$*"
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${level}" "${message}" | tee -a "${LOG_FILE}" >&2
}

info() {
  log "INFO" "$*"
}

warn() {
  log "WARN" "$*"
}

error() {
  log "ERROR" "$*"
}

die() {
  error "$*"
  usage
  exit 1
}

command_exists() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1
}

require_command() {
  local cmd="$1"
  if ! command_exists "${cmd}"; then
    die "Required command not found: ${cmd}"
  fi
}

verbose() {
  if [[ "${VERBOSE}" == "true" ]]; then
    info "$*"
  fi
}

configure_gh_auth() {
  if [[ -n "${GH_TOKEN:-}" ]]; then
    verbose "Using existing GH_TOKEN from environment."
    return 0
  fi

  if [[ -n "${GITHUB_TOKEN_CONTENT_PRIVATE:-}" ]]; then
    export GH_TOKEN="${GITHUB_TOKEN_CONTENT_PRIVATE}"
    verbose "Using GH_TOKEN from GITHUB_TOKEN_CONTENT_PRIVATE."
    return 0
  fi

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    verbose "Using existing GITHUB_TOKEN from environment."
    return 0
  fi

  verbose "No token environment variable found. Falling back to stored gh authentication, if available."
}

is_git_repository() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

get_origin_url() {
  git config --get remote.origin.url 2>/dev/null || true
}

parse_github_repo_from_url() {
  local remote_url="$1"
  local repo=""

  case "${remote_url}" in
  git@github.com:*.git)
    repo="${remote_url#git@github.com:}"
    repo="${repo%.git}"
    ;;
  git@github.com:*)
    repo="${remote_url#git@github.com:}"
    ;;
  ssh://git@github.com/*/*.git)
    repo="${remote_url#ssh://git@github.com/}"
    repo="${repo%.git}"
    ;;
  ssh://git@github.com/*/*)
    repo="${remote_url#ssh://git@github.com/}"
    ;;
  https://github.com/*/*.git)
    repo="${remote_url#https://github.com/}"
    repo="${repo%.git}"
    ;;
  https://github.com/*/*)
    repo="${remote_url#https://github.com/}"
    ;;
  *)
    return 1
    ;;
  esac

  if [[ "${repo}" =~ ^[^/]+/[^/]+$ ]]; then
    printf '%s\n' "${repo}"
    return 0
  fi

  return 1
}

detect_current_repo() {
  local remote_url=""
  local repo=""

  if ! is_git_repository; then
    die "No --repo provided and current directory is not inside a git repository."
  fi

  remote_url="$(get_origin_url)"

  if [[ -z "${remote_url}" ]]; then
    die "No --repo provided and no remote.origin.url found in the current git repository."
  fi

  if ! repo="$(parse_github_repo_from_url "${remote_url}")"; then
    die "Could not derive OWNER/REPO from remote.origin.url: ${remote_url}"
  fi

  printf '%s\n' "${repo}"
}

run_gh_label_create() {
  local repo="$1"
  local name="$2"
  local color="$3"
  local description="$4"

  if [[ "${APPLY}" != "true" ]]; then
    printf 'DRY-RUN gh label create %q --repo %q --color %q --description %q --force\n' \
      "${name}" "${repo}" "${color}" "${description}"
    return 0
  fi

  gh label create "${name}" \
    --repo "${repo}" \
    --color "${color}" \
    --description "${description}" \
    --force >/dev/null
}

apply_labels_to_repo() {
  local repo="$1"

  info "Processing ${repo}"

  run_gh_label_create "${repo}" "type:bug" "9580FF" "Bugfixes in codebase when something is not working."
  run_gh_label_create "${repo}" "type:enhancement" "9580FF" "New enhancements and features."
  run_gh_label_create "${repo}" "type:dependencies" "9580FF" "Dependencies and upstream updates."
  run_gh_label_create "${repo}" "type:documentation" "9580FF" "Improvements or additions to docs."
  run_gh_label_create "${repo}" "type:refactor" "9580FF" "Code refactoring."
  run_gh_label_create "${repo}" "type:data" "9580FF" "Issues pertaining to data or data preparations."
  run_gh_label_create "${repo}" "type:tests" "9580FF" "Issues related to tests."
  run_gh_label_create "${repo}" "type:chore" "9580FF" "Maintenance, housekeeping, or non-feature routine work."

  run_gh_label_create "${repo}" "status:unconfirmed" "80FFEA" "Reported but not yet confirmed."
  run_gh_label_create "${repo}" "status:confirmed" "80FFEA" "Confirmed and accepted as valid work."
  run_gh_label_create "${repo}" "status:in-progress" "80FFEA" "Work is currently in progress."
  run_gh_label_create "${repo}" "status:blocked" "80FFEA" "Work is blocked by another issue, dependency, or decision."
  run_gh_label_create "${repo}" "status:review" "80FFEA" "Work is ready for review or validation."
  run_gh_label_create "${repo}" "status:done" "66CCBB" "Work is done from a workflow perspective."

  run_gh_label_create "${repo}" "resolution:duplicate" "FF80BF" "Closed because the issue already exists elsewhere."
  run_gh_label_create "${repo}" "resolution:invalid" "FF80BF" "Closed because the report or request is not valid."
  run_gh_label_create "${repo}" "resolution:wont-fix" "FF80BF" "Closed with a decision not to implement or fix."
  run_gh_label_create "${repo}" "resolution:completed" "CC6699" "Closed because the work was completed."

  run_gh_label_create "${repo}" "prio:critical" "FF9580" "Requires immediate attention."
  run_gh_label_create "${repo}" "prio:high" "FFCA80" "High priority."
  run_gh_label_create "${repo}" "prio:medium" "FFFF80" "Medium priority."
  run_gh_label_create "${repo}" "prio:low" "8AFF80" "Low priority."

  run_gh_label_create "${repo}" "meta:question" "708CA9" "Further clarification or discussion is needed."
  run_gh_label_create "${repo}" "meta:help-wanted" "708CA9" "External or additional help is welcome."
  run_gh_label_create "${repo}" "meta:keep-open" "708CA9" "Keep the issue open intentionally."
}

run_gh_label_delete() {
  local repo="$1"
  local name="$2"

  if [[ "${APPLY}" != "true" ]]; then
    printf 'DRY-RUN gh label delete %q --repo %q --yes\n' "${name}" "${repo}"
    return 0
  fi

  gh label delete "${name}" --repo "${repo}" --yes >/dev/null
}

clear_labels_for_repo() {
  local repo="$1"
  local label_name=""

  info "Clearing existing labels for ${repo}"

  while IFS= read -r label_name; do
    [[ -n "${label_name}" ]] || continue
    run_gh_label_delete "${repo}" "${label_name}"
  done < <(gh api --paginate "repos/${repo}/labels?per_page=100" --jq '.[].name')
}

VERBOSE="false"
APPLY="false"
CLEAR="false"
declare -a REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
  --repo)
    shift
    [[ $# -gt 0 ]] || die "Missing value for --repo"
    REPOS+=("$1")
    ;;
  --apply)
    APPLY="true"
    ;;
  --clear)
    CLEAR="true"
    ;;
  --verbose)
    VERBOSE="true"
    ;;
  --help)
    usage
    exit 0
    ;;
  *)
    die "Unknown option: $1"
    ;;
  esac
  shift
done

require_command "gh"
require_command "git"

configure_gh_auth

if ! gh auth status >/dev/null 2>&1; then
  die "GitHub CLI is not authenticated. Set GITHUB_TOKEN_CONTENT_PRIVATE, GH_TOKEN, or run 'gh auth login' first."
fi

main() {
  local detected_repo=""
  local repo=""

  verbose "Log file: ${LOG_FILE}"
  verbose "Apply mode: ${APPLY}"
  verbose "Clear mode: ${CLEAR}"

  if [[ "${APPLY}" != "true" ]]; then
    info "Running in DRY-RUN mode. Use --apply to execute changes."
  fi

  if [[ ${#REPOS[@]} -eq 0 ]]; then
    detected_repo="$(detect_current_repo)"
    REPOS=("${detected_repo}")
    info "No --repo provided. Using detected current repository: ${detected_repo}"
  fi

  for repo in "${REPOS[@]}"; do
    if [[ "${CLEAR}" == "true" ]]; then
      clear_labels_for_repo "${repo}"
    fi
    apply_labels_to_repo "${repo}"
  done

  if [[ "${APPLY}" == "true" ]]; then
    info "Label update completed."
  else
    info "Dry run completed."
  fi
}

main "$@"
