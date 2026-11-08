#!/bin/bash
#
# Offline tests for configs/agents/install-skills.sh.
#
# The tests copy the manager into a temporary dotfiles tree and use a
# temporary HOME. All tracked skills already exist there, so the skills CLI
# and the network are never needed. Restoring, hash mismatches during a
# restore, and --update need the network; README.md describes how to test
# them by hand.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
DOTFILES_DIR="$(cd -- "${SOURCE_DIR}/../.." && pwd)"

if ! command -v node >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
  printf 'SKIP: install-skills tests need node and npx in PATH\n' >&2
  exit 0
fi

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "${TMP_ROOT}"' EXIT

ROOT="${TMP_ROOT}/dotfiles"
PROJECT="${ROOT}/configs/agents"
CANONICAL="${PROJECT}/.agents/skills"
TEST_HOME="${TMP_ROOT}/home"
CLAUDE="${TEST_HOME}/.claude/skills"
CODEX="${TEST_HOME}/.codex/skills"

mkdir -p "${ROOT}/bashrc/lib" "${PROJECT}" "${CANONICAL}" "${TEST_HOME}"
cp -a -- "${DOTFILES_DIR}/bashrc/lib/00-core" "${ROOT}/bashrc/lib/"
cp -- "${SOURCE_DIR}/install-skills.sh" "${SOURCE_DIR}/skills-state.ts" "${PROJECT}/"

fail() {
  printf 'FAIL: %s\n' "${1}" >&2
  exit 1
}

# Run the manager; stdout and stderr go to OUTPUT, the exit code to STATUS.
OUTPUT=''
STATUS=0
manager() {
  STATUS=0
  OUTPUT="$(env -u DNB_VERBOSE HOME="${TEST_HOME}" NO_COLOR=1 \
    /bin/bash "${PROJECT}/install-skills.sh" "$@" 2>&1 </dev/null)" || STATUS=$?
}

expect_status() {
  local expected="${1}"
  shift
  manager "$@"
  if [[ "${STATUS}" != "${expected}" ]]; then
    printf '%s\n' "${OUTPUT}" >&2
    fail "install-skills.sh $* exited ${STATUS}, expected ${expected}"
  fi
}

expect_output() {
  if [[ "${OUTPUT}" != *"${1}"* ]]; then
    printf '%s\n' "${OUTPUT}" >&2
    fail "output does not contain: ${1}"
  fi
}

# Create a skill directory and a version 1 lockfile with its real hash.
make_skill() {
  mkdir -p "${CANONICAL}/${1}/scripts"
  printf -- '---\nname: %s\ndescription: Test skill.\n---\n' "${1}" >"${CANONICAL}/${1}/SKILL.md"
  printf 'echo %s\n' "${1}" >"${CANONICAL}/${1}/scripts/run.sh"
}

write_lockfile() {
  local name='' hash='' first='true'

  {
    printf '{\n  "version": 1,\n  "skills": {'
    for name in "$@"; do
      hash="$(node "${PROJECT}/skills-state.ts" --hash "${CANONICAL}/${name}")"
      [[ "${first}" == 'true' ]] || printf ','
      first='false'
      printf '\n    "%s": {"source": "test/%s", "sourceType": "github", "skillPath": "SKILL.md", "computedHash": "%s"}' "${name}" "${name}" "${hash}"
    done
    printf '\n  }\n}\n'
  } >"${PROJECT}/skills-lock.json"
}

make_skill alpha
make_skill beta
write_lockfile alpha beta
mkdir -p "${CLAUDE}/unmanaged-dir"
ln -s /nonexistent/elsewhere/unmanaged-link "${CLAUDE}/unmanaged-link"

# Help and usage errors.
expect_status 0
expect_output 'Usage: install-skills.sh'
expect_status 2 --check --install
expect_status 2 --update --force
expect_status 2 --unknown

# Fresh workstation: every tracked skill is linked for every agent.
expect_status 0 --install --yes
for name in alpha beta; do
  [[ "$(readlink -- "${CLAUDE}/${name}")" == "${CANONICAL}/${name}" ]] || fail "missing Claude link for ${name}"
  [[ "$(readlink -- "${CODEX}/${name}")" == "${CANONICAL}/${name}" ]] || fail "missing Codex link for ${name}"
done
expect_status 0 --check --strict

# Repeated installation changes nothing.
before="$(find "${CLAUDE}" "${CODEX}" "${PROJECT}/.agents" -printf '%p %l %T@\n' | sort)"
expect_status 0 --install --yes
expect_output '0 created, 0 repaired, 4 unchanged'
after="$(find "${CLAUDE}" "${CODEX}" "${PROJECT}/.agents" -printf '%p %l %T@\n' | sort)"
[[ "${before}" == "${after}" ]] || fail 'a repeated install changed files'

# Unmanaged entries stay untouched.
[[ -d "${CLAUDE}/unmanaged-dir" ]] || fail 'unmanaged directory was removed'
[[ "$(readlink -- "${CLAUDE}/unmanaged-link")" == '/nonexistent/elsewhere/unmanaged-link' ]] || fail 'unmanaged link was changed'

# Broken and wrongly targeted managed links are reported and repaired.
ln -sfn "${CANONICAL}/does-not-exist" "${CLAUDE}/alpha"
ln -sfn "${CANONICAL}/beta" "${CODEX}/alpha"
expect_status 1 --check
expect_output "Managed link ${CLAUDE}/alpha points to"
expect_output "Managed link ${CODEX}/alpha points to"
expect_status 0 --install --dry-run
[[ "$(readlink -- "${CLAUDE}/alpha")" == "${CANONICAL}/does-not-exist" ]] || fail 'dry run changed a link'
expect_status 0 --install --yes
expect_output '0 created, 2 repaired, 2 unchanged'
[[ "$(readlink -- "${CODEX}/alpha")" == "${CANONICAL}/alpha" ]] || fail 'wrong link was not repaired'

# A conflicting unmanaged entry is an error and is not overwritten.
rm -- "${CODEX}/beta"
mkdir -- "${CODEX}/beta"
expect_status 1 --install --yes
expect_output "Conflict: ${CODEX}/beta is an unmanaged directory"
[[ -d "${CODEX}/beta" && ! -L "${CODEX}/beta" ]] || fail 'conflicting directory was overwritten'
rmdir -- "${CODEX}/beta"
expect_status 0 --install --yes

# Local changes to a tracked skill are detected and the skill is not linked.
printf 'local change\n' >>"${CANONICAL}/beta/SKILL.md"
expect_status 1 --check
expect_output "Skill 'beta' differs from its lockfile hash"
make_skill beta

# A skill removed from the lockfile is reported; pruning needs approval and
# removes only managed entries.
write_lockfile alpha
expect_status 0 --install --yes
expect_output "Orphaned managed link ${CLAUDE}/beta"
expect_output "Untracked directory ${CANONICAL}/beta"
expect_status 1 --check --strict
expect_status 0 --prune --dry-run
[[ -L "${CLAUDE}/beta" ]] || fail 'prune dry run removed a link'
expect_status 3 --prune
[[ -L "${CLAUDE}/beta" ]] || fail 'prune without confirmation removed a link'
expect_status 0 --prune --yes
[[ ! -e "${CLAUDE}/beta" && ! -L "${CLAUDE}/beta" && ! -e "${CODEX}/beta" && ! -e "${CANONICAL}/beta" ]] || fail 'prune left managed entries'
[[ -L "${CLAUDE}/alpha" && -d "${CLAUDE}/unmanaged-dir" && -L "${CLAUDE}/unmanaged-link" ]] || fail 'prune removed entries it does not own'

# Unexpected per-agent directories in the project are reported.
mkdir -p "${PROJECT}/.claude/skills"
expect_status 0 --check
expect_output "Unexpected directory ${PROJECT}/.claude"
rm -rf -- "${PROJECT}/.claude"

# Invalid lockfiles fail clearly.
printf '{"version": 1, "skills": {"../escape": {"source": "x", "computedHash": "x"}}}\n' >"${PROJECT}/skills-lock.json"
expect_status 1 --check
expect_output 'is not a safe skill directory name'

# --list shows managed and unmanaged entries.
write_lockfile alpha
expect_status 0 --list
expect_output 'unmanaged-dir'
[[ "${OUTPUT}" =~ alpha[[:space:]]+managed ]] || fail 'list does not show alpha as managed'

printf 'PASS: install-skills manager\n'
