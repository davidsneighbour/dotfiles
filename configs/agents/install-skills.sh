#!/bin/bash
#
# install-skills.sh - manage third-party agent skills tracked in skills-lock.json.
#
# The skills CLI (https://github.com/vercel-labs/skills) restores the skills
# recorded in skills-lock.json into .agents/skills/ next to this script. This
# script then links every verified skill into the global agent skill
# directories. A global entry is "managed" only when it is a symbolic link into
# .agents/skills/ of this folder. Everything else is unmanaged and never
# changed. --add and --adopt also move skills that were installed globally
# with `skills add -g` into the tracked project. See README.md in this folder.
# bin/agent-skills exposes this script on PATH.

set -Eeuo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_NAME="${SCRIPT_PATH##*/}"
# The command name on PATH (bin/agent-skills). Used in help and hints.
COMMAND_NAME='agent-skills'
PROJECT_DIR="$(dirname "${SCRIPT_PATH}")"
DOTFILES_DIR="$(cd "${PROJECT_DIR}/../.." && pwd)"
LOCKFILE="${PROJECT_DIR}/skills-lock.json"
CANONICAL_DIR="${PROJECT_DIR}/.agents/skills"
STATE_HELPER="${PROJECT_DIR}/skills-state.ts"

# Pinned skills CLI. Restoration is experimental upstream: re-test
# experimental_install, update -p, and the hash in skills-state.ts before you
# change this version.
SKILLS_CLI_VERSION='1.7.6'
SKILLS_CLI_PACKAGE="skills@${SKILLS_CLI_VERSION}"

# Every tracked skill gets one symbolic link in each of these directories.
AGENT_TARGETS=(
  "${HOME}/.claude/skills"
  "${HOME}/.codex/skills"
)

# Directories where an agent can also find a skill. A tracked skill that is
# also installed here, outside this manager, is reported by --check.
SHADOW_ROOTS=(
  "${HOME}/.agents/skills"
)

# Global scope of the skills CLI (`skills add -g`): its skill directory and
# its lockfile (schema version 3). Verified with the pinned CLI version.
GLOBAL_SKILLS_DIR="${HOME}/.agents/skills"
GLOBAL_LOCKFILE="${HOME}/.agents/.skill-lock.json"

# Directories that belong in this folder. --check reports any other
# directory, for example one that the skills CLI created for another agent.
PROJECT_SUBDIRS=(
  .agents
  tests
)

LOG_DIR="${HOME}/.logs/agent-skills"
LOCK_FILE="${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles/agent-skills.lock"

# A safe skill directory name (the same rule as skills-state.ts).
SKILL_NAME_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]*$'

EXIT_FAILURE=1
EXIT_USAGE=2
EXIT_DEPENDENCY=3

ACTION=''
SOURCE_ARG=''
DRY_RUN='false'
ASSUME_YES='false'
STRICT='false'
FORCE='false'
QUIET='false'
ERRORS=0
WARNINGS=0
NPX_BIN=''
NODE_BIN=''
CANONICAL_REAL=''
WORK_DIR=''

declare -a LOCKED_NAMES=()
declare -a UNLOCKED_NAMES=()
declare -A LOCKED_STATE=()
declare -A LOCKED_SOURCE=()
declare -a SKILL_ARGS=()
declare -a GLOBAL_NAMES=()
declare -A GLOBAL_SOURCE=()
declare -A GLOBAL_ADD_SOURCE=()
# Planned by --add and --adopt: the sources to add, the skills per source
# (space-separated, '*' for all), and the skill names asked for explicitly.
declare -a ADD_SOURCES=()
declare -A ADD_SKILLS=()
declare -a REQUESTED_NAMES=()

print_help() {
  cat <<EOF
Usage: ${COMMAND_NAME} <operation> [options]
       (the same as ${PROJECT_DIR}/${SCRIPT_NAME})

Restore the third-party agent skills recorded in skills-lock.json and link
them into the global agent skill directories:
$(printf '  %s\n' "${AGENT_TARGETS[@]}")
Skills are restored with the pinned skills CLI (${SKILLS_CLI_PACKAGE}) into
  ${CANONICAL_DIR}

Operations (choose one):
  --add        Add skills from --source to the lockfile, restore them, and
               link them. Without --skill, all skills of the source are added.
               A skill that is also installed globally with the skills CLI
               (npx skills add -g) is removed from the global scope first.
               Needs confirmation or --yes.
  --adopt      Move skills that were installed globally with the skills CLI
               into the lockfile: remove each global install, add it here, and
               link it. Without --skill, all global installs are adopted.
               Needs confirmation or --yes.
  --install    Restore missing skills from the lockfile (never updates them),
               verify their content hashes, and create or repair the managed
               links. Network access is needed only for missing skills.
  --check      Verify the lockfile, the installed skills, and the links.
               Also reports global skills CLI installs that are not tracked.
               Read-only and offline.
  --update     Update the tracked skills in a temporary copy, show the
               lockfile diff, and apply it after confirmation.
  --list       Print a table of managed, missing, modified, and unmanaged
               skills with their link state per agent.
  --prune      Remove managed links and restored skill directories that are
               no longer in the lockfile. Needs confirmation or --yes.

Options:
  --source SOURCE
               --add: the skill source, as for npx skills add, for example
               owner/repository or https://github.com/owner/repository.
  --skill NAME --add, --adopt: the skill to add or adopt. Repeat it for more
               skills. '*' means all skills.
  --dry-run    Show what --add, --adopt, --install, --update, or --prune
               would change, without changing anything. --update --dry-run
               reports available updates.
  --yes        Do not ask for confirmation (--add, --adopt, --update, --prune).
  --strict     Exit with status 1 on warnings too, for example orphaned
               links, untracked skill directories, or an uncommitted lockfile.
  --force      --install: also reinstall skills whose content differs from
               the lockfile. The local copy is restored if this fails.
  --verbose    Show every operation and the skills CLI output.
  --quiet      Show only warnings and errors. Disables --verbose.
  --help       Show this help.

Ownership:
  A global entry is managed only when it is a symbolic link into
  ${CANONICAL_DIR}.
  Unmanaged directories, files, and links (for example from skillz) are never
  changed. A name conflict is an error and nothing is overwritten.
  The only exception: --add and --adopt remove the global skills CLI install
  (${GLOBAL_SKILLS_DIR}/<name> and its links) of the skills
  that they add, after confirmation.

Exit status:
  0  Success.
  1  A problem was found or an operation failed (see the messages).
  2  Usage error.
  3  A required tool (Node.js, npx) is missing, or confirmation was needed
     but no terminal was available (use --yes).

Log:
  ${LOG_DIR}/YYYYMMDD-HHMMSS.log

Examples:
  ${COMMAND_NAME} --add --source greensock/gsap-skills --dry-run
  ${COMMAND_NAME} --add --source blader/humanizer --skill humanizer
  ${COMMAND_NAME} --adopt --dry-run
  ${COMMAND_NAME} --adopt --skill gsap-core --skill gsap-react
  ${COMMAND_NAME} --install --yes
  ${COMMAND_NAME} --install --dry-run
  ${COMMAND_NAME} --check --strict
  ${COMMAND_NAME} --list
  ${COMMAND_NAME} --update --dry-run
  ${COMMAND_NAME} --update
  ${COMMAND_NAME} --prune --dry-run
EOF
}

usage_error() {
  printf '%s: %s\n\n' "${SCRIPT_NAME}" "${1}" >&2
  print_help >&2
  exit "${EXIT_USAGE}"
}

load_libraries() {
  local lib_dir="${DOTFILES_DIR}/bashrc/lib/00-core"
  local lib=''

  for lib in dnb-core-colors dnb-core-log dnb-core-ui-theme dnb-core-ui; do
    if [[ ! -r "${lib_dir}/${lib}.bash" ]]; then
      printf '%s: missing library %s/%s.bash\n' "${SCRIPT_NAME}" "${lib_dir}" "${lib}" >&2
      exit "${EXIT_DEPENDENCY}"
    fi
    # shellcheck source=/dev/null
    source "${lib_dir}/${lib}.bash"
  done

  mkdir -p "${LOG_DIR}"
  DNB_SETUP_LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S).log"
  export DNB_SETUP_LOG_FILE
}

verbose() {
  if [[ "${DNB_VERBOSE:-}" == '1' ]]; then
    dnb_log info "${1}"
  fi
}

report_error() {
  ERRORS=$((ERRORS + 1))
  dnb_ui_error "${1}"
}

report_warning() {
  WARNINGS=$((WARNINGS + 1))
  dnb_ui_warning "${1}"
}

cleanup() {
  if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
    rm -rf -- "${WORK_DIR}"
  fi
}

# Find node and npx. PATH comes first (mise, nvm, or system Node). The stable
# ~/.local/bin/node-cron runtime from scripts/node-cron.sh is the fallback for
# shells without Node in PATH.
require_runtime() {
  local cron_node="${HOME}/.local/bin/node-cron"
  local node_dir=''

  NODE_BIN="$(command -v node 2>/dev/null || printf '')"
  NPX_BIN="$(command -v npx 2>/dev/null || printf '')"

  if [[ -z "${NODE_BIN}" || -z "${NPX_BIN}" ]] && [[ -x "${cron_node}" ]]; then
    node_dir="$(dirname "$(readlink -f "${cron_node}")")"
    if [[ -x "${node_dir}/node" && -x "${node_dir}/npx" ]]; then
      NODE_BIN="${node_dir}/node"
      NPX_BIN="${node_dir}/npx"
      PATH="${node_dir}:${PATH}"
      export PATH
      verbose "Using the node-cron runtime in ${node_dir}"
    fi
  fi

  if [[ -z "${NODE_BIN}" || -z "${NPX_BIN}" ]]; then
    dnb_ui_error "Node.js and npx are required, but were not found in PATH or through ${cron_node}."
    dnb_ui_error "Install Node.js (mise or NVM), or run: /bin/bash ${DOTFILES_DIR}/scripts/node-cron.sh --refresh"
    exit "${EXIT_DEPENDENCY}"
  fi
  verbose "node: ${NODE_BIN} ($("${NODE_BIN}" --version))"
  verbose "npx: ${NPX_BIN}"
}

# Serialise the operations that change files.
acquire_lock() {
  if ! command -v flock >/dev/null 2>&1; then
    report_warning 'flock is not available; concurrent runs are not prevented.'
    return 0
  fi
  mkdir -p "$(dirname "${LOCK_FILE}")"
  exec 9>"${LOCK_FILE}"
  if ! flock --nonblock 9; then
    dnb_ui_error "Another ${SCRIPT_NAME} run holds ${LOCK_FILE}. Wait for it to finish."
    exit "${EXIT_FAILURE}"
  fi
}

# Run the pinned skills CLI in DIRECTORY. Output goes to the log file (and to
# stderr with --verbose). Telemetry is disabled; stdin is closed, so the CLI
# cannot prompt.
run_skills_cli() {
  local directory="${1}"
  local status=0 output='' line=''
  shift

  output="$(mktemp)"
  verbose "Running in ${directory}: npx ${SKILLS_CLI_PACKAGE} $*"
  printf '\n$ (cd %s && npx --yes %s %s)\n' "${directory}" "${SKILLS_CLI_PACKAGE}" "$*" >>"${DNB_SETUP_LOG_FILE}"
  (cd "${directory}" && DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 "${NPX_BIN}" --yes "${SKILLS_CLI_PACKAGE}" "$@" </dev/null 2>&1) |
    sed -u 's/\x1b\[[0-9;?]*[A-Za-z]//g' >"${output}" || status=$?
  cat -- "${output}" >>"${DNB_SETUP_LOG_FILE}"
  if [[ "${DNB_VERBOSE:-}" == '1' ]]; then
    cat -- "${output}" >&2
  elif ((status != 0)); then
    # Show the CLI's own error lines, so the cause is visible without the log.
    while IFS= read -r line; do
      dnb_ui_error "skills CLI: ${line}"
    done < <(grep -E -i 'failed|cannot|error|not up to date|changed since' -- "${output}" | sed -E 's/^[^[:alnum:]]+//' | head -n 5)
  fi
  rm -f -- "${output}"
  return "${status}"
}

# Fill LOCKED_* and UNLOCKED_NAMES from the lockfile and the skill directory
# in SKILLS_DIR (default: the canonical directory).
read_state() {
  local lockfile="${1:-${LOCKFILE}}"
  local skills_dir="${2:-${CANONICAL_DIR}}"
  local output='' kind='' name='' source='' state=''

  LOCKED_NAMES=()
  UNLOCKED_NAMES=()
  LOCKED_STATE=()
  LOCKED_SOURCE=()

  if [[ ! -f "${lockfile}" ]]; then
    dnb_ui_error "Lockfile not found: ${lockfile}"
    dnb_ui_error "Restore it from Git: git -C ${DOTFILES_DIR} checkout -- ${lockfile#"${DOTFILES_DIR}/"}"
    exit "${EXIT_FAILURE}"
  fi
  if [[ ! -f "${STATE_HELPER}" ]]; then
    dnb_ui_error "Helper not found: ${STATE_HELPER}"
    exit "${EXIT_FAILURE}"
  fi

  if ! output="$("${NODE_BIN}" "${STATE_HELPER}" --lockfile "${lockfile}" --skills-dir "${skills_dir}")"; then
    dnb_ui_error "Cannot read ${lockfile}. See the message above."
    exit "${EXIT_FAILURE}"
  fi

  while IFS=$'\t' read -r kind name source state; do
    [[ -n "${kind}" ]] || continue
    case "${kind}" in
      locked)
        LOCKED_NAMES+=("${name}")
        LOCKED_STATE["${name}"]="${state}"
        LOCKED_SOURCE["${name}"]="${source}"
        ;;
      unlocked) UNLOCKED_NAMES+=("${name}") ;;
      *)
        dnb_ui_error "Unexpected helper output: ${kind}"
        exit "${EXIT_FAILURE}"
        ;;
    esac
  done <<<"${output}"
  verbose "Lockfile: ${#LOCKED_NAMES[@]} skill(s); ${#UNLOCKED_NAMES[@]} untracked directory(ies) in ${skills_dir}"
}

is_locked() {
  [[ -n "${LOCKED_STATE[${1}]+set}" ]]
}

# Fill GLOBAL_* from the global skills CLI lockfile (`skills add -g`). A
# missing lockfile means no global installs. With MODE 'strict' an unreadable
# lockfile is fatal (--add, --adopt); otherwise it is a warning.
read_global_state() {
  local mode="${1:-warn}"
  local output='' kind='' name='' source='' add_source=''

  GLOBAL_NAMES=()
  GLOBAL_SOURCE=()
  GLOBAL_ADD_SOURCE=()

  if ! output="$("${NODE_BIN}" "${STATE_HELPER}" --global-lockfile "${GLOBAL_LOCKFILE}")"; then
    if [[ "${mode}" == 'strict' ]]; then
      dnb_ui_error "Cannot read the global skills CLI lockfile ${GLOBAL_LOCKFILE}. See the message above. Nothing was changed."
      exit "${EXIT_FAILURE}"
    fi
    report_warning "Cannot read the global skills CLI lockfile ${GLOBAL_LOCKFILE}. Global installs are not checked."
    return 0
  fi

  while IFS=$'\t' read -r kind name source add_source; do
    [[ "${kind}" == 'global' ]] || continue
    GLOBAL_NAMES+=("${name}")
    GLOBAL_SOURCE["${name}"]="${source}"
    GLOBAL_ADD_SOURCE["${name}"]="${add_source}"
  done <<<"${output}"
  verbose "Global skills CLI lockfile: ${#GLOBAL_NAMES[@]} skill(s) in ${GLOBAL_LOCKFILE}"
}

is_global() {
  [[ -n "${GLOBAL_SOURCE[${1}]+set}" ]]
}

# True if ROOT/NAME is a link that the skills CLI created for a global
# install: it points to GLOBAL_SKILLS_DIR/NAME.
is_global_cli_link() {
  local path="${1}/${2}"
  local target=''

  [[ -L "${path}" ]] || return 1
  target="$(readlink -- "${path}")"
  [[ "${target}" == /* ]] || target="${1}/${target}"
  [[ "$(realpath -m -- "${target}")" == "$(realpath -m -- "${GLOBAL_SKILLS_DIR}/${2}")" ]]
}

# Print the state of ROOT/NAME:
#   absent        nothing there
#   ok            managed link to the canonical skill
#   broken        managed link whose target does not exist
#   wrong         managed link to another canonical skill
#   foreign-link  link that points somewhere else (unmanaged)
#   foreign-dir   real directory (unmanaged)
#   foreign-file  other file (unmanaged)
link_state() {
  local path="${1}/${2}"
  local target='' parent=''

  if [[ -L "${path}" ]]; then
    target="$(readlink -- "${path}")"
    [[ "${target}" == /* ]] || target="${1}/${target}"
    while [[ "${target}" == */ ]]; do
      target="${target%/}"
    done
    # Every managed target ends in .agents/skills/<name>. Skip the realpath
    # call for all other links (for example the skillz links).
    if [[ "${target}" != *.agents/skills/* ]]; then
      printf 'foreign-link'
      return 0
    fi
    parent="$(realpath -m -- "${target%/*}")"
    if [[ "${parent}" != "${CANONICAL_REAL}" ]]; then
      printf 'foreign-link'
    elif [[ "${target##*/}" != "${2}" ]]; then
      printf 'wrong'
    elif [[ -d "${path}" ]]; then
      printf 'ok'
    else
      printf 'broken'
    fi
  elif [[ -d "${path}" ]]; then
    printf 'foreign-dir'
  elif [[ -e "${path}" ]]; then
    printf 'foreign-file'
  else
    printf 'absent'
  fi
}

is_managed_link() {
  case "$(link_state "${1}" "${2}")" in
    ok | broken | wrong) return 0 ;;
    *) return 1 ;;
  esac
}

# Print the names of the managed links in ROOT that are not in the lockfile,
# one per line. One find call reads all link targets; only links whose target
# can be managed get the full check.
orphaned_links() {
  local root="${1}"
  local name='' target=''

  [[ -d "${root}" ]] || return 0
  while IFS= read -r -d '' name && IFS= read -r -d '' target; do
    is_locked "${name}" && continue
    [[ "${target}" == *.agents/skills/* ]] || continue
    if is_managed_link "${root}" "${name}"; then
      printf '%s\n' "${name}"
    fi
  done < <(find "${root}" -mindepth 1 -maxdepth 1 -type l -printf '%f\0%l\0')
}

report_orphans() {
  local root="${1}"
  local name=''

  while IFS= read -r name; do
    report_warning "Orphaned managed link ${root}/${name}: '${name}' is not in the lockfile. Run --prune to remove it."
  done < <(orphaned_links "${root}")
}

# Create or replace a link without a window where the name is missing.
place_link() {
  local path="${1}"
  local target="${2}"
  local temporary="${path}.install-skills.$$"

  ln -s -- "${target}" "${temporary}"
  mv -T -f -- "${temporary}" "${path}"
}

conflict_message() {
  local path="${1}"
  local state="${2}"

  case "${state}" in
    foreign-link) printf '%s is an unmanaged link to %s' "${path}" "$(readlink -- "${path}")" ;;
    foreign-dir) printf '%s is an unmanaged directory' "${path}" ;;
    *) printf '%s is an unmanaged file' "${path}" ;;
  esac
}

# Make every verified skill available in every agent target. Never changes
# unmanaged entries. Reports orphaned managed links.
sync_links() {
  local root='' name='' state='' path=''
  local created=0 repaired=0 unchanged=0

  for root in "${AGENT_TARGETS[@]}"; do
    if [[ -e "${root}" && ! -d "${root}" ]]; then
      report_error "Agent skill directory ${root} exists but is not a directory. Skipped."
      continue
    fi
    if [[ ! -d "${root}" ]]; then
      if [[ "${DRY_RUN}" == 'true' ]]; then
        dnb_ui_info "Would create ${root}"
      else
        mkdir -p -- "${root}"
        verbose "Created ${root}"
      fi
    fi

    for name in "${LOCKED_NAMES[@]}"; do
      path="${root}/${name}"
      if [[ "${LOCKED_STATE[${name}]}" != 'ok' ]]; then
        verbose "Not linking ${name}: content is ${LOCKED_STATE[${name}]}"
        continue
      fi
      state="$(link_state "${root}" "${name}")"
      case "${state}" in
        ok)
          unchanged=$((unchanged + 1))
          ;;
        absent | broken | wrong)
          if [[ "${DRY_RUN}" == 'true' ]]; then
            dnb_ui_info "Would link ${path} -> ${CANONICAL_DIR}/${name}"
          else
            place_link "${path}" "${CANONICAL_DIR}/${name}"
            verbose "Linked ${path} -> ${CANONICAL_DIR}/${name}"
          fi
          if [[ "${state}" == 'absent' ]]; then
            created=$((created + 1))
          else
            repaired=$((repaired + 1))
          fi
          ;;
        *)
          report_error "Conflict: $(conflict_message "${path}" "${state}"). Not overwritten. Remove or rename it, or remove '${name}' from the lockfile."
          ;;
      esac
    done

    report_orphans "${root}"
  done

  if [[ "${DRY_RUN}" == 'true' ]]; then
    dnb_ui_info "Links: ${created} to create, ${repaired} to repair, ${unchanged} unchanged."
  else
    dnb_ui_success "Links: ${created} created, ${repaired} repaired, ${unchanged} unchanged."
  fi
}

report_unlocked() {
  local name=''

  for name in "${UNLOCKED_NAMES[@]}"; do
    report_warning "Untracked directory ${CANONICAL_DIR}/${name}: not in the lockfile. Run --prune to remove it."
  done
}

# Problems that block a skill from being linked.
report_content_problems() {
  local name=''

  for name in "${LOCKED_NAMES[@]}"; do
    case "${LOCKED_STATE[${name}]}" in
      ok) ;;
      missing) report_error "Skill '${name}' is missing from ${CANONICAL_DIR}. Run --install." ;;
      modified) report_error "Skill '${name}' differs from its lockfile hash. Run --install --force to restore the recorded content." ;;
      *) report_error "${CANONICAL_DIR}/${name} is not a directory. Remove it, then run --install." ;;
    esac
  done
}

action_install() {
  local name='' backup_dir='' lock_copy='' restore_status=0
  local -a to_restore=() to_force=()

  require_runtime
  [[ "${DRY_RUN}" == 'true' ]] || acquire_lock
  read_state

  for name in "${LOCKED_NAMES[@]}"; do
    case "${LOCKED_STATE[${name}]}" in
      missing) to_restore+=("${name}") ;;
      modified)
        if [[ "${FORCE}" == 'true' ]]; then
          to_force+=("${name}")
        fi
        ;;
      *) ;;
    esac
  done

  if ((${#LOCKED_NAMES[@]} == 0)); then
    dnb_ui_info 'The lockfile tracks no skills.'
  elif ((${#to_restore[@]} + ${#to_force[@]} == 0)); then
    dnb_ui_info "All ${#LOCKED_NAMES[@]} tracked skill(s) are present; nothing to restore."
  elif [[ "${DRY_RUN}" == 'true' ]]; then
    for name in "${to_restore[@]}"; do
      dnb_ui_info "Would restore '${name}' from ${LOCKED_SOURCE[${name}]}"
    done
    for name in "${to_force[@]}"; do
      dnb_ui_info "Would reinstall modified '${name}' from ${LOCKED_SOURCE[${name}]}"
    done
  else
    mkdir -p -- "${CANONICAL_DIR}"
    if ((${#to_force[@]} > 0)); then
      backup_dir="$(mktemp -d "${PROJECT_DIR}/.agents/.restore-backup.XXXXXX")"
      for name in "${to_force[@]}"; do
        mv -T -- "${CANONICAL_DIR}/${name}" "${backup_dir}/${name}"
      done
    fi

    dnb_ui_info "Restoring $((${#to_restore[@]} + ${#to_force[@]})) skill(s) with ${SKILLS_CLI_PACKAGE}..."
    WORK_DIR="$(mktemp -d)"
    lock_copy="${WORK_DIR}/skills-lock.json"
    cp -- "${LOCKFILE}" "${lock_copy}"
    run_skills_cli "${PROJECT_DIR}" experimental_install --frozen-lockfile || restore_status=$?

    # --frozen-lockfile must never change the lockfile. Guard against CLI
    # regressions: put the original bytes back.
    if ! cmp -s -- "${lock_copy}" "${LOCKFILE}"; then
      cp -- "${lock_copy}" "${LOCKFILE}"
      report_error 'The skills CLI changed the lockfile during a frozen restore. The original lockfile was put back.'
      restore_status=1
    fi

    if [[ -n "${backup_dir}" ]]; then
      for name in "${to_force[@]}"; do
        if ((restore_status != 0)) || [[ ! -f "${CANONICAL_DIR}/${name}/SKILL.md" ]]; then
          rm -rf -- "${CANONICAL_DIR:?}/${name}"
          mv -T -- "${backup_dir}/${name}" "${CANONICAL_DIR}/${name}"
          dnb_ui_warning "Kept the local copy of '${name}' because the reinstall failed."
        fi
      done
      rm -rf -- "${backup_dir}"
    fi

    if ((restore_status != 0)); then
      report_error "The restore failed (exit ${restore_status}). Skills that were already installed and the lockfile were not changed. Check network access and the sources. A hash mismatch means that the source changed: run --update. Log: ${DNB_SETUP_LOG_FILE}"
    fi
    read_state
  fi

  if [[ "${DRY_RUN}" != 'true' ]]; then
    report_content_problems
  fi
  report_unlocked
  sync_links
}

# Report project directories that the skills CLI created for other agents.
check_project_dirs() {
  local entry='' expected='' known=''

  for entry in "${PROJECT_DIR}"/* "${PROJECT_DIR}"/.[!.]*; do
    [[ -d "${entry}" ]] || continue
    known='false'
    for expected in "${PROJECT_SUBDIRS[@]}"; do
      [[ "${entry}" == "${PROJECT_DIR}/${expected}" ]] && known='true'
    done
    [[ "${known}" == 'true' ]] && continue
    report_warning "Unexpected directory ${entry}: the skills CLI installs only into .agents/skills here. Review and remove it."
  done
}

check_lockfile_git() {
  local relative="${LOCKFILE#"${DOTFILES_DIR}/"}"

  command -v git >/dev/null 2>&1 || return 0
  git -C "${DOTFILES_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  if ! git -C "${DOTFILES_DIR}" ls-files --error-unmatch -- "${relative}" >/dev/null 2>&1; then
    report_warning "${relative} is not tracked by Git yet. Commit it."
  elif ! git -C "${DOTFILES_DIR}" diff --quiet HEAD -- "${relative}"; then
    report_warning "${relative} has uncommitted changes. Review them with: git -C ${DOTFILES_DIR} diff -- ${relative}"
  fi
}

action_check() {
  local root='' name='' state=''

  require_runtime
  read_state
  verbose "Pinned skills CLI: ${SKILLS_CLI_PACKAGE}"

  report_content_problems
  report_unlocked

  for root in "${AGENT_TARGETS[@]}"; do
    if [[ ! -d "${root}" ]]; then
      if ((${#LOCKED_NAMES[@]} > 0)); then
        report_error "Agent skill directory ${root} does not exist. Run --install."
      fi
      continue
    fi
    for name in "${LOCKED_NAMES[@]}"; do
      state="$(link_state "${root}" "${name}")"
      case "${state}" in
        ok) verbose "ok ${root}/${name}" ;;
        absent) report_error "Missing link ${root}/${name}. Run --install." ;;
        broken) report_error "Broken managed link ${root}/${name}. Run --install to repair it." ;;
        wrong) report_error "Managed link ${root}/${name} points to $(readlink -- "${root}/${name}"). Run --install to repair it." ;;
        *) report_error "Conflict: $(conflict_message "${root}/${name}" "${state}")." ;;
      esac
    done
    report_orphans "${root}"
  done

  read_global_state

  for root in "${SHADOW_ROOTS[@]}"; do
    for name in "${LOCKED_NAMES[@]}"; do
      if [[ -e "${root}/${name}" || -L "${root}/${name}" ]] && ! is_managed_link "${root}" "${name}"; then
        if is_global "${name}"; then
          report_warning "'${name}' is also installed globally with the skills CLI at ${root}/${name}. Agents can load it twice. Remove the global install: ${COMMAND_NAME} --adopt --skill ${name}"
        else
          report_warning "'${name}' is also installed outside this manager at ${root}/${name}. Agents can load it twice. Review and remove it."
        fi
      fi
    done
  done

  for name in "${GLOBAL_NAMES[@]}"; do
    is_locked "${name}" && continue
    report_warning "'${name}' is installed globally with the skills CLI (from ${GLOBAL_SOURCE[${name}]}) and is not tracked in the lockfile. Track it: ${COMMAND_NAME} --adopt --skill ${name}"
  done

  check_project_dirs
  check_lockfile_git

  if ((ERRORS == 0 && WARNINGS == 0)); then
    dnb_ui_success "All ${#LOCKED_NAMES[@]} tracked skill(s) are installed, verified, and linked."
  fi
}

target_label() {
  local label="${1%/skills}"

  label="${label##*/}"
  printf '%s' "${label#.}"
}

# Print one table row: NAME STATUS SOURCE, then the link state per target.
list_row() {
  local name="${1}"
  local root=''
  local -a cells=("${name}" "${2}" "${3}")

  for root in "${AGENT_TARGETS[@]}"; do
    cells+=("$(link_state "${root}" "${name}")")
  done
  (
    IFS=$'\t'
    printf '%s\n' "${cells[*]}"
  )
}

action_list() {
  local root='' name='' entry='' state='' table=''
  local -a header=(NAME STATUS SOURCE)
  local -A seen=() orphaned=()

  require_runtime
  read_state
  read_global_state
  WORK_DIR="$(mktemp -d)"
  table="${WORK_DIR}/skills.tsv"

  for root in "${AGENT_TARGETS[@]}"; do
    header+=("$(target_label "${root}")")
  done
  (
    IFS=$'\t'
    printf '%s\n' "${header[*]}"
  ) >"${table}"

  for name in "${LOCKED_NAMES[@]}"; do
    seen["${name}"]=1
    case "${LOCKED_STATE[${name}]}" in
      ok) state='managed' ;;
      *) state="${LOCKED_STATE[${name}]}" ;;
    esac
    list_row "${name}" "${state}" "${LOCKED_SOURCE[${name}]}" >>"${table}"
  done

  for name in "${UNLOCKED_NAMES[@]}"; do
    seen["${name}"]=1
    list_row "${name}" 'untracked' '-' >>"${table}"
  done

  for root in "${AGENT_TARGETS[@]}"; do
    while IFS= read -r name; do
      orphaned["${name}"]=1
    done < <(orphaned_links "${root}")
  done

  for root in "${AGENT_TARGETS[@]}"; do
    [[ -d "${root}" ]] || continue
    for entry in "${root}"/* "${root}"/.[!.]*; do
      [[ -e "${entry}" || -L "${entry}" ]] || continue
      name="${entry##*/}"
      [[ -z "${seen[${name}]+set}" ]] || continue
      seen["${name}"]=1
      if [[ -n "${orphaned[${name}]+set}" ]]; then
        list_row "${name}" 'orphaned' '-' >>"${table}"
      elif is_global "${name}"; then
        list_row "${name}" 'global' "${GLOBAL_SOURCE[${name}]}" >>"${table}"
      else
        list_row "${name}" 'unmanaged' '-' >>"${table}"
      fi
    done
  done

  # Global installs that no agent target shows (for example Codex reads
  # ~/.agents/skills directly).
  for name in "${GLOBAL_NAMES[@]}"; do
    [[ -z "${seen[${name}]+set}" ]] || continue
    seen["${name}"]=1
    list_row "${name}" 'global' "${GLOBAL_SOURCE[${name}]}" >>"${table}"
  done

  dnb_ui_table --input "${table}"
}

confirm_or_exit() {
  local prompt="${1}"
  local status=0

  [[ "${ASSUME_YES}" == 'true' ]] && return 0
  dnb_ui_confirm --prompt "${prompt}" || status=$?
  case "${status}" in
    0) return 0 ;;
    3)
      dnb_ui_error 'Confirmation needed, but no terminal is available. Run again with --yes.'
      exit "${EXIT_DEPENDENCY}"
      ;;
    *)
      dnb_ui_info 'Cancelled. Nothing was changed.'
      exit 0
      ;;
  esac
}

# Copy the lockfile and the restored skills to STAGE. The skills CLI runs
# there and not in the project, because `add` and `update` can also write
# directories for other agents (for example .claude/ or agent/).
make_stage() {
  local stage="${1}"

  mkdir -p -- "${stage}/.agents"
  cp -- "${LOCKFILE}" "${stage}/skills-lock.json"
  if [[ -d "${CANONICAL_DIR}" ]]; then
    cp -a -- "${CANONICAL_DIR}" "${stage}/.agents/skills"
  fi
}

action_update() {
  local stage='' name='' status=0 relative="${LOCKFILE#"${DOTFILES_DIR}/"}"
  local -a changed=() removed=()

  require_runtime
  [[ "${DRY_RUN}" == 'true' ]] || acquire_lock
  read_state

  if ((${#LOCKED_NAMES[@]} == 0)); then
    dnb_ui_info 'The lockfile tracks no skills; nothing to update.'
    return 0
  fi
  if [[ "${DRY_RUN}" != 'true' ]] && git -C "${DOTFILES_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
    ! git -C "${DOTFILES_DIR}" diff --quiet HEAD -- "${relative}" 2>/dev/null; then
    dnb_ui_error "${relative} has uncommitted changes. Commit or discard them first, so that the update diff stays reviewable."
    exit "${EXIT_FAILURE}"
  fi

  WORK_DIR="$(mktemp -d)"
  stage="${WORK_DIR}/project"
  make_stage "${stage}"

  dnb_ui_info "Checking ${#LOCKED_NAMES[@]} tracked skill(s) for updates with ${SKILLS_CLI_PACKAGE}..."
  run_skills_cli "${stage}" update --project --yes || status=$?
  if ((status != 0)); then
    report_error "The skills CLI update failed (exit ${status}). Nothing was changed. See ${DNB_SETUP_LOG_FILE}"
    return 0
  fi

  if cmp -s -- "${LOCKFILE}" "${stage}/skills-lock.json"; then
    dnb_ui_success 'All tracked skills are up to date.'
    return 0
  fi

  # diff exits 1 when the files differ, which cmp has already established.
  status=0
  diff -u --label "a/${relative}" --label "b/${relative}" -- "${LOCKFILE}" "${stage}/skills-lock.json" >"${WORK_DIR}/lockfile.diff" || status=$?
  if ((status > 1)); then
    report_error "Cannot compare the lockfiles (diff exit ${status}). Nothing was changed."
    return 0
  fi
  dnb_ui_info 'Updates are available. Lockfile changes:'
  dnb_ui_diff --file "${WORK_DIR}/lockfile.diff"

  # Verify the staged content against the new lockfile before using it.
  read_state "${stage}/skills-lock.json" "${stage}/.agents/skills"
  for name in "${LOCKED_NAMES[@]}"; do
    if [[ "${LOCKED_STATE[${name}]}" != 'ok' ]]; then
      report_error "The updated copy of '${name}' does not match the new lockfile (${LOCKED_STATE[${name}]}). Nothing was changed."
    fi
  done
  ((ERRORS == 0)) || return 0

  # Compare the new lockfile with the current content: these skills change.
  read_state "${stage}/skills-lock.json" "${CANONICAL_DIR}"
  for name in "${LOCKED_NAMES[@]}"; do
    [[ "${LOCKED_STATE[${name}]}" == 'ok' ]] || changed+=("${name}")
  done
  for name in "${UNLOCKED_NAMES[@]}"; do
    removed+=("${name}")
  done

  if [[ "${DRY_RUN}" == 'true' ]]; then
    for name in "${changed[@]}"; do
      dnb_ui_info "Would update '${name}' from ${LOCKED_SOURCE[${name}]}"
    done
    for name in "${removed[@]}"; do
      dnb_ui_info "Would stop tracking '${name}' (its files stay until --prune)"
    done
    return 0
  fi

  confirm_or_exit "Apply these updates to ${relative}?"

  for name in "${changed[@]}"; do
    rm -rf -- "${CANONICAL_DIR}/.update-${name}.$$"
    cp -a -- "${stage}/.agents/skills/${name}" "${CANONICAL_DIR}/.update-${name}.$$"
    rm -rf -- "${CANONICAL_DIR:?}/${name}"
    mv -T -- "${CANONICAL_DIR}/.update-${name}.$$" "${CANONICAL_DIR}/${name}"
    verbose "Updated ${CANONICAL_DIR}/${name}"
  done
  cp -- "${stage}/skills-lock.json" "${LOCKFILE}.update.$$"
  mv -f -- "${LOCKFILE}.update.$$" "${LOCKFILE}"

  read_state
  report_content_problems
  sync_links
  for name in "${removed[@]}"; do
    report_warning "'${name}' is no longer in the lockfile. Run --prune to remove its files and links."
  done
  dnb_ui_success "Updated ${#changed[@]} skill(s). Review and commit ${relative}: git -C ${DOTFILES_DIR} diff -- ${relative}"
}

# Check that NAME can be linked into every agent target. REMOVES_GLOBAL is
# 'true' when the global skills CLI install of NAME is removed first.
#
# `skills remove -g NAME` deletes ~/.agents/skills/NAME and also
# ~/.claude/skills/NAME, even when that is a link to somewhere else (verified
# with the pinned CLI). For this reason only the links that the CLI created
# itself, and managed links (they are linked again afterwards), are accepted.
preflight_name() {
  local name="${1}"
  local removes_global="${2}"
  local root='' state='' path=''

  for root in "${AGENT_TARGETS[@]}"; do
    state="$(link_state "${root}" "${name}")"
    case "${state}" in
      absent | ok | broken | wrong) ;;
      foreign-link)
        if [[ "${removes_global}" == 'true' ]] && is_global_cli_link "${root}" "${name}"; then
          continue
        fi
        report_error "Conflict: $(conflict_message "${root}/${name}" "${state}")."
        ;;
      *) report_error "Conflict: $(conflict_message "${root}/${name}" "${state}")." ;;
    esac
  done

  for root in "${SHADOW_ROOTS[@]}"; do
    path="${root}/${name}"
    [[ -e "${path}" || -L "${path}" ]] || continue
    is_managed_link "${root}" "${name}" && continue
    if [[ "${removes_global}" == 'true' && "${root}" == "${GLOBAL_SKILLS_DIR}" && -d "${path}" && ! -L "${path}" ]]; then
      continue
    fi
    report_error "Conflict: $(conflict_message "${path}" "$(link_state "${root}" "${name}")"), and it is not a global skills CLI install (for example a skillz link to one of your own skills)."
  done
}

# Carry out the plan in ADD_SOURCES, ADD_SKILLS, and REQUESTED_NAMES (see
# action_add and action_adopt):
#   1. Run `skills add` for every source in a staged copy of the project.
#   2. Verify the staged lockfile and content. Tracked skills must not change.
#   3. Check every new skill for conflicts in the agent directories.
#   4. After confirmation: remove the matching global skills CLI installs,
#      install the new skills, replace the lockfile, and link.
# Nothing changes before step 4. Errors are counted in ERRORS.
apply_add() {
  local stage='' source='' name='' kind='' status=0 output='' verb='Add' remove_verb='Remove'
  local relative="${LOCKFILE#"${DOTFILES_DIR}/"}"
  local -a skills=() added=() remove_global=()
  local -A added_source=() planned=() requested=()

  WORK_DIR="$(mktemp -d)"
  stage="${WORK_DIR}/project"
  make_stage "${stage}"

  for source in "${ADD_SOURCES[@]}"; do
    skills=()
    if [[ "${ADD_SKILLS[${source}]}" != '*' ]]; then
      read -r -a skills <<<"${ADD_SKILLS[${source}]}"
      skills=(--skill "${skills[@]}")
    fi
    dnb_ui_info "Fetching ${source} with ${SKILLS_CLI_PACKAGE}..."
    status=0
    run_skills_cli "${stage}" add "${source}" "${skills[@]}" --agent codex --yes || status=$?
    if ((status != 0)); then
      report_error "The skills CLI could not add ${source} (exit ${status}). Check the source and the skill names (list them: npx ${SKILLS_CLI_PACKAGE} add ${source} --list). Nothing was changed."
      return 0
    fi
  done

  if ! output="$("${NODE_BIN}" "${STATE_HELPER}" --lockfile "${stage}/skills-lock.json" --compare "${LOCKFILE}")"; then
    report_error 'Cannot compare the staged lockfile with the current one. See the message above. Nothing was changed.'
    return 0
  fi
  while IFS=$'\t' read -r kind name; do
    case "${kind}" in
      '') ;;
      added) added+=("${name}") ;;
      changed) report_error "'${name}' is already tracked, and adding it again changes its lockfile entry (content or source). --add does not change tracked skills: run --update. Nothing was changed." ;;
      removed) report_error "The skills CLI removed '${name}' from the staged lockfile. Nothing was changed." ;;
      *) report_error "Unexpected helper output: ${kind}" ;;
    esac
  done <<<"${output}"
  ((ERRORS == 0)) || return 0

  # Verify the staged content against the staged lockfile.
  read_state "${stage}/skills-lock.json" "${stage}/.agents/skills"
  for name in "${added[@]}"; do
    added_source["${name}"]="${LOCKED_SOURCE[${name}]}"
    if [[ "${LOCKED_STATE[${name}]}" != 'ok' ]]; then
      report_error "The staged copy of '${name}' does not match its new lockfile entry (${LOCKED_STATE[${name}]}). Nothing was changed."
    fi
  done
  # A skill of a staged source that is also installed globally from the same
  # source: its global install is removed, even when it is tracked already.
  for name in "${LOCKED_NAMES[@]}"; do
    is_global "${name}" || continue
    for source in "${ADD_SOURCES[@]}"; do
      [[ "${GLOBAL_ADD_SOURCE[${name}]}" == "${source}" ]] && requested["${name}"]=1
    done
  done
  ((ERRORS == 0)) || return 0

  read_state
  for name in "${REQUESTED_NAMES[@]}"; do
    requested["${name}"]=1
    if ! is_locked "${name}" && [[ -z "${added_source[${name}]+set}" ]]; then
      report_error "'${name}' was not found in the requested source(s). List the skills of a source: npx ${SKILLS_CLI_PACKAGE} add <source> --list. Nothing was changed."
    fi
  done
  ((ERRORS == 0)) || return 0

  for name in "${added[@]}" "${!requested[@]}"; do
    [[ -z "${planned[${name}]+set}" ]] || continue
    planned["${name}"]=1
    if is_global "${name}"; then
      remove_global+=("${name}")
      preflight_name "${name}" 'true'
    elif [[ -n "${added_source[${name}]+set}" ]]; then
      preflight_name "${name}" 'false'
    fi
  done
  if ((ERRORS > 0)); then
    dnb_ui_error 'Resolve the conflicts above, then run the command again. Nothing was changed.'
    dnb_ui_error "For a skillz link to one of your own skills: remove that skill from its source repository and run skillz, or keep your own skill and remove only the global install (npx ${SKILLS_CLI_PACKAGE} remove -g <name>, then run skillz)."
    return 0
  fi

  if ((${#added[@]} + ${#remove_global[@]} == 0)); then
    dnb_ui_success 'Nothing to do: the requested skills are already tracked and not installed globally.'
    return 0
  fi
  if [[ "${DRY_RUN}" == 'true' ]]; then
    verb='Would add'
    remove_verb='Would remove'
  fi
  for name in "${added[@]}"; do
    dnb_ui_info "${verb} '${name}' from ${added_source[${name}]}"
  done
  for name in "${remove_global[@]}"; do
    dnb_ui_info "${remove_verb} the global skills CLI install of '${name}' (${GLOBAL_SOURCE[${name}]}) at ${GLOBAL_SKILLS_DIR}/${name}"
  done
  [[ "${DRY_RUN}" != 'true' ]] || return 0

  confirm_or_exit "Add ${#added[@]} skill(s) to ${relative} and remove ${#remove_global[@]} global install(s)?"

  if ((${#remove_global[@]} > 0)); then
    status=0
    run_skills_cli "${WORK_DIR}" remove --global "${remove_global[@]}" --yes || status=$?
    if ((status != 0)); then
      report_error "The skills CLI could not remove the global install(s) (exit ${status}). The lockfile was not changed. Check the global state: npx ${SKILLS_CLI_PACKAGE} ls -g"
      return 0
    fi
    read_global_state strict
    for name in "${remove_global[@]}"; do
      if is_global "${name}"; then
        report_error "'${name}' is still in ${GLOBAL_LOCKFILE} after the removal. The lockfile was not changed."
      fi
    done
    ((ERRORS == 0)) || return 0
  fi

  if ((${#added[@]} > 0)); then
    mkdir -p -- "${CANONICAL_DIR}"
    for name in "${added[@]}"; do
      rm -rf -- "${CANONICAL_DIR}/.add-${name}.$$"
      cp -a -- "${stage}/.agents/skills/${name}" "${CANONICAL_DIR}/.add-${name}.$$"
      rm -rf -- "${CANONICAL_DIR:?}/${name}"
      mv -T -- "${CANONICAL_DIR}/.add-${name}.$$" "${CANONICAL_DIR}/${name}"
      verbose "Installed ${CANONICAL_DIR}/${name}"
    done
    cp -- "${stage}/skills-lock.json" "${LOCKFILE}.add.$$"
    mv -f -- "${LOCKFILE}.add.$$" "${LOCKFILE}"
  fi

  read_state
  report_content_problems
  sync_links
  if ((${#remove_global[@]} > 0)); then
    dnb_ui_success "Removed ${#remove_global[@]} global skills CLI install(s)."
  fi
  if ((${#added[@]} > 0)); then
    dnb_ui_success "Added ${#added[@]} skill(s). Read them before use: skills run with full agent permissions. Then commit ${relative}: git -C ${DOTFILES_DIR} diff -- ${relative}"
  fi
}

action_add() {
  local skill=''

  require_runtime
  [[ "${DRY_RUN}" == 'true' ]] || acquire_lock
  read_state
  read_global_state strict

  ADD_SOURCES=("${SOURCE_ARG}")
  ADD_SKILLS["${SOURCE_ARG}"]="${SKILL_ARGS[*]}"
  for skill in "${SKILL_ARGS[@]}"; do
    if [[ "${skill}" == '*' ]]; then
      ADD_SKILLS["${SOURCE_ARG}"]='*'
      REQUESTED_NAMES=()
      break
    fi
    REQUESTED_NAMES+=("${skill}")
  done
  if ((${#SKILL_ARGS[@]} == 0)); then
    ADD_SKILLS["${SOURCE_ARG}"]='*'
  fi

  apply_add
}

action_adopt() {
  local name='' source=''
  local -a selected=()

  require_runtime
  [[ "${DRY_RUN}" == 'true' ]] || acquire_lock
  read_state
  read_global_state strict

  if ((${#GLOBAL_NAMES[@]} == 0)); then
    dnb_ui_success "No skills are installed globally with the skills CLI (${GLOBAL_LOCKFILE}). Nothing to adopt."
    return 0
  fi

  # No --skill (or '*') selects every global install.
  ((${#SKILL_ARGS[@]} > 0)) || selected=("${GLOBAL_NAMES[@]}")
  for name in "${SKILL_ARGS[@]}"; do
    if [[ "${name}" == '*' ]]; then
      selected=("${GLOBAL_NAMES[@]}")
      break
    fi
    if ! is_global "${name}"; then
      report_error "'${name}' is not installed globally with the skills CLI (it is not in ${GLOBAL_LOCKFILE})."
      continue
    fi
    selected+=("${name}")
  done
  ((ERRORS == 0)) || return 0

  for name in "${selected[@]}"; do
    if is_locked "${name}"; then
      # Already tracked: only the global install is removed.
      REQUESTED_NAMES+=("${name}")
      continue
    fi
    source="${GLOBAL_ADD_SOURCE[${name}]}"
    if [[ "${source}" == '-' ]]; then
      report_warning "Skipped '${name}': its source (${GLOBAL_SOURCE[${name}]}) is not a remote repository, so other workstations cannot restore it."
      continue
    fi
    REQUESTED_NAMES+=("${name}")
    if [[ -z "${ADD_SKILLS[${source}]+set}" ]]; then
      ADD_SOURCES+=("${source}")
      ADD_SKILLS["${source}"]="${name}"
    else
      ADD_SKILLS["${source}"]+=" ${name}"
    fi
  done

  if ((${#REQUESTED_NAMES[@]} == 0)); then
    dnb_ui_info 'Nothing to adopt.'
    return 0
  fi
  apply_add
}

action_prune() {
  local root='' name='' entry=''
  local -a links=() dirs=()

  require_runtime
  [[ "${DRY_RUN}" == 'true' ]] || acquire_lock
  read_state

  for root in "${AGENT_TARGETS[@]}"; do
    while IFS= read -r name; do
      links+=("${root}/${name}")
    done < <(orphaned_links "${root}")
  done
  for name in "${UNLOCKED_NAMES[@]}"; do
    dirs+=("${CANONICAL_DIR}/${name}")
  done

  if ((${#links[@]} + ${#dirs[@]} == 0)); then
    dnb_ui_success 'Nothing to prune.'
    return 0
  fi
  for entry in "${links[@]}"; do
    dnb_ui_info "$([[ "${DRY_RUN}" == 'true' ]] && printf 'Would remove' || printf 'Remove') managed link ${entry}"
  done
  for entry in "${dirs[@]}"; do
    dnb_ui_info "$([[ "${DRY_RUN}" == 'true' ]] && printf 'Would remove' || printf 'Remove') untracked skill ${entry}"
  done
  [[ "${DRY_RUN}" != 'true' ]] || return 0

  confirm_or_exit "Remove ${#links[@]} link(s) and ${#dirs[@]} skill directory(ies)?"
  for entry in "${links[@]}"; do
    rm -f -- "${entry}"
  done
  for entry in "${dirs[@]}"; do
    rm -rf -- "${entry}"
  done
  dnb_ui_success "Removed ${#links[@]} link(s) and ${#dirs[@]} skill directory(ies)."
}

set_action() {
  if [[ -n "${ACTION}" && "${ACTION}" != "${1}" ]]; then
    usage_error "choose only one operation (--${ACTION} and --${1} given)."
  fi
  ACTION="${1}"
}

main() {
  if (($# == 0)); then
    print_help
    exit 0
  fi

  while (($# > 0)); do
    case "${1}" in
      --help | -h)
        print_help
        exit 0
        ;;
      --add) set_action add ;;
      --adopt) set_action adopt ;;
      --source)
        (($# > 1)) || usage_error '--source needs a value.'
        [[ "${2}" != -* ]] || usage_error "--source needs a value, not the option ${2}."
        SOURCE_ARG="${2}"
        shift
        ;;
      --skill)
        (($# > 1)) || usage_error '--skill needs a value.'
        [[ "${2}" == '*' || "${2}" =~ ${SKILL_NAME_PATTERN} ]] || usage_error "--skill: '${2}' is not a valid skill name."
        SKILL_ARGS+=("${2}")
        shift
        ;;
      --install) set_action install ;;
      --check) set_action check ;;
      --update) set_action update ;;
      --list) set_action list ;;
      --prune) set_action prune ;;
      --dry-run) DRY_RUN='true' ;;
      --yes) ASSUME_YES='true' ;;
      --strict) STRICT='true' ;;
      --force) FORCE='true' ;;
      --verbose) export DNB_VERBOSE='1' ;;
      --quiet) QUIET='true' ;;
      *) usage_error "unknown option: ${1}" ;;
    esac
    shift
  done

  [[ -n "${ACTION}" ]] || usage_error 'choose an operation: --add, --adopt, --install, --check, --update, --list, or --prune.'
  if [[ "${ACTION}" == 'add' && -z "${SOURCE_ARG}" ]]; then
    usage_error '--add needs --source <source>, for example --source owner/repository.'
  fi
  if [[ -n "${SOURCE_ARG}" && "${ACTION}" != 'add' ]]; then
    usage_error '--source is only valid with --add.'
  fi
  if ((${#SKILL_ARGS[@]} > 0)) && [[ "${ACTION}" != 'add' && "${ACTION}" != 'adopt' ]]; then
    usage_error '--skill is only valid with --add and --adopt.'
  fi
  if [[ "${FORCE}" == 'true' && "${ACTION}" != 'install' ]]; then
    usage_error '--force is only valid with --install.'
  fi
  if [[ "${QUIET}" == 'true' ]]; then
    unset DNB_VERBOSE
    export DNB_UI_QUIET='1'
  fi

  load_libraries
  trap cleanup EXIT
  CANONICAL_REAL="$(realpath -m -- "${CANONICAL_DIR}")"
  verbose "${SCRIPT_NAME} --${ACTION} (dry run: ${DRY_RUN}); log: ${DNB_SETUP_LOG_FILE}"

  "action_${ACTION}"

  if ((ERRORS > 0)); then
    dnb_ui_error "${ERRORS} error(s), ${WARNINGS} warning(s). Log: ${DNB_SETUP_LOG_FILE}"
    exit "${EXIT_FAILURE}"
  fi
  if [[ "${STRICT}" == 'true' ]] && ((WARNINGS > 0)); then
    dnb_ui_error "${WARNINGS} warning(s) with --strict. Log: ${DNB_SETUP_LOG_FILE}"
    exit "${EXIT_FAILURE}"
  fi
}

main "$@"
