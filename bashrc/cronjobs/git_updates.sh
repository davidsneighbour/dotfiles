#!/bin/bash
#
# repo-auto-update.sh
#
# Safely auto-update multiple git repos from a config file.
# - Reads JSON, YAML, or TOML.
# - Expands ~, $HOME, and ${HOME} in paths.
# - Derives path/url from minimal config: type+slug [+protocol, +domain].
# - Clones missing repos when "url" is provided or derivable.
# - Fetches full history, all remote branches, and all tags (offline-ready).
# - Only updates when working tree is clean and update is fast-forwardable.
# - Sends Discord notifications on issues and continues.
#
# Cron example:
# 17 3 * * * /path/to/repo-auto-update.sh --config /path/to/repos.toml --verbose >> "$HOME/.logs/repos/auto-update-$(date +\%Y\%m\%d-\%H\%M\%S).log" 2>&1
#
# Requirements:
#   - jq for JSON configs
#   - yq (mikefarah) for YAML configs
#   - python3 with tomllib (3.11+) or tomli for TOML configs

set -euo pipefail
IFS=$'\n\t'

CONFIG_FILE=""
DRY_RUN=false
VERBOSE=false
DISCORD_WEBHOOK_OVERRIDE=""

LOG_DIR="${HOME}/.logs/repos"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/auto-update-$(date +%Y%m%d-%H%M%S).log"

# --- Logging ---------------------------------------------------------------

log() {
  local level="${1:-INFO}"
  shift || true
  local msg="${*:-}"
  printf '[%s] %s %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "${level}" "${msg}" | tee -a "${LOG_FILE}"
}

vlog() { if "${VERBOSE}"; then log "DEBUG" "$@"; fi; }

die() { log "ERROR" "$*"; exit 1; }

print_help() {
  cat <<'EOF'
Usage:
  repo-auto-update.sh --config <file> [--dry-run] [--verbose] [--discord-webhook <url>] [--help]

Options:
  --config <file>           Required. Path to config file (JSON, YAML, or TOML).
  --dry-run                 Do not apply changes, only simulate and report.
  --verbose                 Enable verbose logging.
  --discord-webhook <url>   Override webhook URL from .env files.
  --help                    Show this help.

Config: each repo item supports both explicit and derived fields.
Required minimal form:
- type      one of: "gitlab", "github" (or specify domain)
- slug      "namespace/repo" (e.g. "wonderland-gmbh/discourse-custom-header-links")

Optional:
- protocol  "ssh" (default) or "https"
- domain    overrides host domain, defaults to "gitlab.com" or "github.com" by type
- path      absolute target dir; if omitted, derived as "${HOME}/{domain}/{slug}"
- url       git URL; if omitted, derived from protocol+domain+slug
- branch    branch to operate on; defaults to current
- remote    remote name; default "origin"
- skip      boolean

TOML example (minimal, derived):
[[repos]]
type = "gitlab"
slug = "wonderland-gmbh/discourse-custom-header-links"

[[repos]]
type = "github"
slug = "davidsneighbour/kollitsch.dev"
protocol = "ssh"  # or "https"

Explicit form still works:
[[repos]]
path = "${HOME}/gitlab.com/wonderland-gmbh/discourse-custom-header-links"
url = "git@gitlab.com:wonderland-gmbh/discourse-custom-header-links.git"
branch = "main"
remote = "origin"
EOF
}

# --- Env loader (./.env first, then ~/.env) ---------------------------------

load_env() {
  local file_local=".env"
  local file_home="${HOME}/.env"
  if [[ -f "${file_local}" ]]; then
    set -a; # shellcheck source=/dev/null
    source "${file_local}"; set +a
    vlog "Loaded env from ${file_local}"
  fi
  if [[ -f "${file_home}" ]]; then
    set -a; # shellcheck source=/dev/null
    source "${file_home}"; set +a
    vlog "Loaded env from ${file_home}"
  fi
}

# --- Discord notification ----------------------------------------------------

notify_discord() {
  local content="" username="Repo Auto Update"
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --content) content="${2:-}"; shift 2;;
      --username) username="${2:-Repo Auto Update}"; shift 2;;
      --help)
        cat <<EOF
${FUNCNAME[0]} --content "text" [--username "Repo Auto Update"]
Send a message to Discord via webhook.
EOF
        return 0;;
      *) log "WARN" "Unknown arg to ${FUNCNAME[0]}: ${1}"; shift;;
    esac
  done
  local webhook="${DISCORD_WEBHOOK_OVERRIDE:-${DISCORD_WEBHOOK:-}}"
  [[ -z "${webhook}" ]] && { vlog "No DISCORD_WEBHOOK configured, skipping Discord notification."; return 0; }
  curl --silent --show-error --location --request POST "${webhook}" \
    --form "content=${content}" \
    --form "username=${username}" >/dev/null 2>&1 || true
}

# --- Path and derivation helpers --------------------------------------------

expand_path() {
  local raw="${1:-}"
  raw="${raw/#\~/$HOME}"
  raw="${raw//\$\{HOME\}/$HOME}"
  raw="${raw//\$HOME/$HOME}"
  echo "${raw}"
}

ensure_parent_dir() {
  local target="${1:-}"
  [[ -n "${target}" ]] || return 0
  local parent; parent="$(dirname "${target}")"
  [[ -d "${parent}" ]] || mkdir -p "${parent}"
}

derive_defaults() {
  # ${FUNCNAME[0]} prints "path|url|domain|protocol"
  # Inputs via env vars for simplicity:
  #   D_TYPE, D_DOMAIN, D_SLUG, D_PROTOCOL, D_PATH, D_URL
  local type="${D_TYPE:-}"
  local domain="${D_DOMAIN:-}"
  local slug="${D_SLUG:-}"
  local protocol="${D_PROTOCOL:-ssh}"
  local path="${D_PATH:-}"
  local url="${D_URL:-}"

  # Normalize type -> domain if domain not given
  if [[ -z "${domain}" && -n "${type}" ]]; then
    case "${type}" in
      gitlab) domain="gitlab.com" ;;
      github) domain="github.com" ;;
      *) ;;
    esac
  fi

  # Derive path if missing and slug+domain exist
  if [[ -z "${path}" && -n "${slug}" && -n "${domain}" ]]; then
    path="${HOME}/${domain}/${slug}"
  fi

  # Derive url if missing and slug+domain exist
  if [[ -z "${url}" && -n "${slug}" && -n "${domain}" ]]; then
    if [[ "${protocol}" == "https" ]]; then
      url="https://${domain}/${slug}.git"
    else
      url="git@${domain}:${slug}.git"
    fi
  fi

  echo "${path}|${url}|${domain}|${protocol}"
}

# --- Config parsing ----------------------------------------------------------
# Output one repo per line as:
# path|branch|remote|skip|url|type|domain|protocol|slug

parse_config() {
  local file=""
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --file) file="${2:-}"; shift 2;;
      --help)
        cat <<EOF
${FUNCNAME[0]} --file <path>
Parse config and print lines:
path|branch|remote|skip|url|type|domain|protocol|slug
EOF
        return 0;;
      *) log "WARN" "Unknown arg to ${FUNCNAME[0]}: ${1}"; shift;;
    esac
  done
  [[ -f "${file}" ]] || die "Config file not found: ${file}"

  local ext="${file##*.}"
  case "${ext}" in
    json|JSON)
      command -v jq >/dev/null 2>&1 || die "jq is required for JSON configs."
      jq -r '
        .repos // [] |
        map({
          path: (.path // ""),
          branch: (.branch // ""),
          remote: (.remote // "origin"),
          skip: (if has("skip") then .skip else false end),
          url: (.url // ""),
          type: (.type // ""),
          domain: (.domain // ""),
          protocol: (.protocol // ""),
          slug: (.slug // "")
        }) |
        .[] |
        "\(.path)|\(.branch)|\(.remote)|\(.skip)|\(.url)|\(.type)|\(.domain)|\(.protocol)|\(.slug)"
      ' "${file}"
      ;;
    yml|yaml|YAML|YML)
      command -v yq >/dev/null 2>&1 || die "yq is required for YAML configs."
      yq -r '
        .repos // [] |
        map({
          path: (.path // ""),
          branch: (.branch // ""),
          remote: (.remote // "origin"),
          skip: (.skip // false),
          url: (.url // ""),
          type: (.type // ""),
          domain: (.domain // ""),
          protocol: (.protocol // ""),
          slug: (.slug // "")
        }) |
        .[] |
        "\(.path)|\(.branch)|\(.remote)|\(.skip)|\(.url)|\(.type)|\(.domain)|\(.protocol)|\(.slug)"
      ' "${file}"
      ;;
    toml|TOML)
      command -v python3 >/dev/null 2>&1 || die "python3 is required for TOML configs."
      python3 - "$file" <<'PY'
import sys
path = sys.argv[1]
try:
    import tomllib  # py311+
except ModuleNotFoundError:
    try:
        import tomli as tomllib
    except ModuleNotFoundError:
        print("ERROR: python tomllib or tomli is required to parse TOML.", file=sys.stderr)
        sys.exit(1)

with open(path, 'rb') as f:
    data = tomllib.load(f)

for r in data.get('repos', []):
    p = r.get('path', '')
    b = r.get('branch', '')
    remote = r.get('remote', 'origin')
    skip = r.get('skip', False)
    url = r.get('url', '')
    typ = r.get('type', '')
    dom = r.get('domain', '')
    proto = r.get('protocol', '')
    slug = r.get('slug', '')
    print(f"{p}|{b}|{remote}|{str(skip).lower()}|{url}|{typ}|{dom}|{proto}|{slug}")
PY
      ;;
    *) die "Unsupported config extension: ${ext}. Use .json, .yaml/.yml, or .toml.";;
  esac
}

# --- Git helpers -------------------------------------------------------------

clone_repo_if_missing() {
  # ${FUNCNAME[0]} --path <dir> --url <git-url> [--remote <name>] [--branch <name>]
  local path="" url="" remote="origin" branch=""
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --path) path="${2:-}"; shift 2;;
      --url) url="${2:-}"; shift 2;;
      --remote) remote="${2:-origin}"; shift 2;;
      --branch) branch="${2:-}"; shift 2;;
      --help)
        cat <<EOF
${FUNCNAME[0]} --path <dir> --url <git-url> [--remote origin] [--branch <name>]
Clone the repository if <dir> does not exist.
EOF
        return 0;;
      *) log "WARN" "Unknown arg to ${FUNCNAME[0]}: ${1}"; shift;;
    esac
  done

  if [[ -d "${path}/.git" ]]; then
    vlog "Repo exists at ${path}"
    return 0
  fi

  [[ -n "${url}" ]] || { notify_discord --content ":warning: ${path}: missing 'url' for cloning."; die "Missing 'url' for ${path}"; }

  log "INFO" "Cloning ${url} into ${path}"
  ensure_parent_dir "${path}"

  if "${DRY_RUN}"; then
    log "INFO" "Dry-run: would run 'git clone ${url} ${path}'"
    return 0
  fi

  git clone "${url}" "${path}" >/dev/null 2>&1 || {
    notify_discord --content ":x: ${path}: git clone failed."; die "git clone failed for ${url}"
  }

  pushd "${path}" >/dev/null || true
  if [[ "${remote}" != "origin" ]]; then
    git remote rename origin "${remote}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${branch}" ]]; then
    if git ls-remote --exit-code --heads "${remote}" "${branch}" >/dev/null 2>&1; then
      git checkout -q "${branch}" || true
    fi
  fi
  popd >/dev/null || true
}

ensure_git_repo() {
  local path=""
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --path) path="${2:-}"; shift 2;;
      --help)
        cat <<EOF
${FUNCNAME[0]} --path <dir>
Check directory and .git presence.
EOF
        return 0;;
      *) log "WARN" "Unknown arg to ${FUNCNAME[0]}: ${1}"; shift;;
    esac
  done
  [[ -d "${path}" ]] || die "Path does not exist: ${path}"
  [[ -d "${path}/.git" ]] || die "Not a git repository: ${path}"
}

is_clean_worktree() { git update-index -q --refresh; [[ -z "$(git status --porcelain)" ]]; }

current_branch() { git rev-parse --abbrev-ref HEAD; }

has_upstream() {
  local br; br="$(current_branch)"
  git rev-parse --abbrev-ref --symbolic-full-name "${br}@{u}" >/dev/null 2>&1
}

fast_forward_possible() {
  local upstream; upstream="$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}")"
  git merge-base --is-ancestor HEAD "${upstream}"
}

ahead_behind_counts() {
  local upstream; upstream="$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}")"
  git rev-list --left-right --count "HEAD...${upstream}" | awk '{print $1" "$2}'
}

fetch_all_complete() {
  # Fetch full history, all branches, all tags; unshallow if needed.
  local remote="${1:-origin}"

  if git rev-parse --is-shallow-repository >/dev/null 2>&1 && [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
    vlog "Unshallowing repository..."
    git fetch --unshallow >/dev/null 2>&1 || true
  fi

  git remote set-branches "${remote}" '*' >/dev/null 2>&1 || true

  git fetch --prune --prune-tags "${remote}" \
    +refs/heads/*:refs/remotes/"${remote}"/* \
    +refs/tags/*:refs/tags/* >/dev/null 2>&1 || return 1

  return 0
}

process_repo() {
  # ${FUNCNAME[0]} --path <dir> [--branch <name>] [--remote <name>] [--url <git-url>]
  local path="" branch="" remote="origin" url=""

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --path) path="${2:-}"; shift 2;;
      --branch) branch="${2:-}"; shift 2;;
      --remote) remote="${2:-origin}"; shift 2;;
      --url) url="${2:-}"; shift 2;;
      --help)
        cat <<EOF
${FUNCNAME[0]} --path <dir> [--branch <name>] [--remote <name>] [--url <git-url>]
Clone if missing, fetch full content, and fast-forward update current branch.
EOF
        return 0;;
      *) log "WARN" "Unknown arg to ${FUNCNAME[0]}: ${1}"; shift;;
    esac
  done

  [[ -n "${path}" ]] || { log "WARN" "Missing --path"; return 1; }

  if [[ ! -d "${path}/.git" ]]; then
    clone_repo_if_missing --path "${path}" --url "${url}" --remote "${remote}" ${branch:+--branch "${branch}"}
    if "${DRY_RUN}"; then
      log "INFO" "Dry-run: skipping post-clone fetch/update for ${path}"
      return 0
    fi
  fi

  log "INFO" "Processing: ${path}"
  ensure_git_repo --path "${path}"
  pushd "${path}" >/dev/null || return 1

  if [[ -n "${branch}" ]]; then
    if git show-ref --verify --quiet "refs/heads/${branch}"; then
      git checkout -q "${branch}"
    else
      if git ls-remote --exit-code --heads "${remote}" "${branch}" >/dev/null 2>&1; then
        git checkout -q -b "${branch}" --track "${remote}/${branch}" || {
          notify_discord --content ":warning: ${path}: cannot checkout branch '${branch}'. Skipping." --username "Repo Auto Update"
          log "WARN" "Cannot checkout ${branch}. Skipping."
          popd >/dev/null || true
          return 0
        }
      else
        notify_discord --content ":warning: ${path}: branch '${branch}' not found remotely. Skipping." --username "Repo Auto Update"
        log "WARN" "Branch '${branch}' not found remotely. Skipping."
        popd >/dev/null || true
        return 0
      fi
    fi
  fi

  local br; br="$(current_branch)"
  vlog "On branch: ${br}"

  if ! has_upstream; then
    if git ls-remote --exit-code --heads "${remote}" "${br}" >/dev/null 2>&1; then
      git branch --set-upstream-to "${remote}/${br}" >/dev/null 2>&1 || true
    else
      notify_discord --content ":grey_question: ${path}: No upstream for branch '${br}' on remote '${remote}'. Skipping." --username "Repo Auto Update"
      log "INFO" "No upstream for ${br} on ${remote}. Skipping."
      popd >/dev/null || true
      return 0
    fi
  fi

  if ! is_clean_worktree; then
    notify_discord --content ":no_entry: ${path}: Working tree not clean on '${br}'. Skipping update." --username "Repo Auto Update"
    log "INFO" "Working tree not clean. Skipping."
    popd >/dev/null || true
    return 0
  fi

  if ! fetch_all_complete "${remote}"; then
    notify_discord --content ":x: ${path}: comprehensive fetch failed." --username "Repo Auto Update"
    log "ERROR" "Comprehensive fetch failed."
    popd >/dev/null || true
    return 1
  fi

  local ahead behind
  read -r ahead behind <<<"$(ahead_behind_counts)"
  vlog "Ahead: ${ahead} Behind: ${behind}"

  if [[ "${behind}" -eq 0 ]]; then
    log "INFO" "Up to date: ${path} (${br})"
    popd >/dev/null || true
    return 0
  fi

  if fast_forward_possible; then
    log "INFO" "Fast-forward available (${behind} commits)."
    if "${DRY_RUN}"; then
      log "INFO" "Dry-run: would run 'git pull --ff-only'."
    else
      if git pull --ff-only >/dev/null 2>&1; then
        log "INFO" "Updated successfully."
      else
        notify_discord --content ":x: ${path}: git pull --ff-only failed unexpectedly." --username "Repo Auto Update"
        log "ERROR" "git pull --ff-only failed."
      fi
    fi
  else
    notify_discord --content ":warning: ${path}: Update not fast-forwardable on '${br}'. Manual intervention required." --username "Repo Auto Update"
    log "INFO" "Not fast-forwardable. Skipping."
  fi

  popd >/dev/null || true
}

# --- CLI ---------------------------------------------------------------------

main() {
  if [[ $# -eq 0 ]]; then print_help; exit 1; fi
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --config) CONFIG_FILE="${2:-}"; shift 2;;
      --dry-run) DRY_RUN=true; shift;;
      --verbose) VERBOSE=true; shift;;
      --discord-webhook) DISCORD_WEBHOOK_OVERRIDE="${2:-}"; shift 2;;
      --help) print_help; exit 0;;
      *) log "WARN" "Unknown argument: ${1}"; print_help; exit 1;;
    esac
  done
  [[ -n "${CONFIG_FILE}" ]] || { print_help; exit 1; }

  load_env

  # Read config and process entries
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    IFS='|' read -r repo_path repo_branch repo_remote repo_skip repo_url repo_type repo_domain repo_protocol repo_slug <<<"${line}"

    # Expand explicit path first, then derive if missing
    repo_path="$(expand_path "${repo_path}")"

    # Derive defaults from type/slug if needed
    D_TYPE="${repo_type}" D_DOMAIN="${repo_domain}" D_SLUG="${repo_slug}" D_PROTOCOL="${repo_protocol}" D_PATH="${repo_path}" D_URL="${repo_url}"
    IFS='|' read -r d_path d_url d_domain d_proto <<<"$(derive_defaults)"

    # Use derived values when missing
    repo_path="${repo_path:-${d_path}}"
    repo_url="${repo_url:-${d_url}}"
    repo_domain="${repo_domain:-${d_domain}}"
    repo_protocol="${repo_protocol:-${d_proto}}"

    if [[ -z "${repo_path}" ]]; then
      log "WARN" "Skipping entry with empty path (missing slug/domain to derive)."
      continue
    fi
    if [[ "${repo_skip}" == "true" ]]; then
      vlog "Skipping repo (skip=true): ${repo_path}"
      continue
    fi

    # Build argv as an array to avoid IFS-based word splitting
    args=( --path "${repo_path}" )
    if [[ -n "${repo_branch}" ]]; then args+=( --branch "${repo_branch}" ); fi
    if [[ -n "${repo_remote}" ]]; then args+=( --remote "${repo_remote}" ); fi
    if [[ -n "${repo_url}"    ]]; then args+=( --url "${repo_url}" ); fi

    process_repo "${args[@]}"
  done < <(parse_config --file "${CONFIG_FILE}")

  log "INFO" "Done."
}

main "$@"
