#!/bin/bash
#
# Offline tests for configs/agents/install-skills.sh.
#
# The tests copy the manager into a temporary dotfiles tree and use a
# temporary HOME. All tracked skills already exist there, so the skills CLI
# and the network are never needed. --add and --adopt run against a fake npx
# that copies skills from local fixture sources and emulates `remove -g`.
# Restoring, hash mismatches during a restore, and --update need the network;
# README.md describes how to test them by hand.

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
# MANAGER_PATH is the PATH of the manager (the fake npx is put first for
# --add and --adopt).
OUTPUT=''
STATUS=0
MANAGER_PATH="${PATH}"
manager() {
  STATUS=0
  OUTPUT="$(env -u DNB_VERBOSE HOME="${TEST_HOME}" NO_COLOR=1 PATH="${MANAGER_PATH}" \
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
expect_output 'Usage: agent-skills'
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

# --add and --adopt -----------------------------------------------------------

# Fake npx for `skills add` (project scope) and `skills remove --global`.
# A source "owner/repo" is the directory FAKE_SOURCES/owner_repo.
FAKE_BIN="${TMP_ROOT}/bin"
FAKE_SOURCES="${TMP_ROOT}/sources"
mkdir -p "${FAKE_BIN}" "${FAKE_SOURCES}"
cat >"${FAKE_BIN}/npx" <<'FAKE'
#!/bin/bash
set -euo pipefail
[[ "${1}" == '--yes' ]] && shift
shift # the skills@VERSION package
command="${1}"
shift
case "${command}" in
  add)
    source="${1}"
    shift
    skills=()
    while (($# > 0)); do
      if [[ "${1}" == '--skill' ]]; then
        shift
        while (($# > 0)) && [[ "${1}" != --* ]]; do
          skills+=("${1}")
          shift
        done
      else
        shift
      fi
    done
    directory="${FAKE_SOURCES}/${source//\//_}"
    [[ -d "${directory}" ]] || { printf 'error: source %s not found\n' "${source}"; exit 1; }
    if ((${#skills[@]} == 0)); then
      mapfile -t skills < <(ls -- "${directory}")
    fi
    mkdir -p .agents/skills
    for skill in "${skills[@]}"; do
      [[ -d "${directory}/${skill}" ]] || { printf 'error: no skill %s\n' "${skill}"; exit 1; }
      rm -rf -- ".agents/skills/${skill}"
      cp -a -- "${directory}/${skill}" ".agents/skills/${skill}"
      hash="$(node "${FAKE_STATE_HELPER}" --hash ".agents/skills/${skill}")"
      node -e '
        const fs = require("node:fs");
        const [name, source, hash] = process.argv.slice(1);
        const lock = JSON.parse(fs.readFileSync("skills-lock.json", "utf8"));
        lock.skills[name] = { source, sourceType: "github", skillPath: "SKILL.md", computedHash: hash };
        fs.writeFileSync("skills-lock.json", JSON.stringify(lock, null, 2) + "\n");
      ' "${skill}" "${source}" "${hash}"
    done
    ;;
  remove)
    for name in "$@"; do
      [[ "${name}" == --* ]] && continue
      rm -rf -- "${HOME}/.agents/skills/${name}" "${HOME}/.claude/skills/${name}"
      node -e '
        const fs = require("node:fs");
        const [file, name] = process.argv.slice(1);
        const lock = JSON.parse(fs.readFileSync(file, "utf8"));
        delete lock.skills[name];
        fs.writeFileSync(file, JSON.stringify(lock, null, 2) + "\n");
      ' "${HOME}/.agents/.skill-lock.json" "${name}"
    done
    ;;
  *)
    printf 'fake npx: unsupported command %s\n' "${command}"
    exit 1
    ;;
esac
FAKE
chmod +x "${FAKE_BIN}/npx"
export FAKE_SOURCES
export FAKE_STATE_HELPER="${PROJECT}/skills-state.ts"
MANAGER_PATH="${FAKE_BIN}:${PATH}"
GLOBAL_DIR="${TEST_HOME}/.agents/skills"
GLOBAL_LOCK="${TEST_HOME}/.agents/.skill-lock.json"

make_source_skill() {
  mkdir -p "${FAKE_SOURCES}/${1}/${2}"
  printf -- '---\nname: %s\ndescription: Source skill %s.\n---\n' "${2}" "${3:-1}" >"${FAKE_SOURCES}/${1}/${2}/SKILL.md"
}

# Emulate `skills add -g SOURCE --skill NAME`: a real directory in
# ~/.agents/skills, a relative Claude link, and a global lockfile entry.
global_install() {
  local source="${1}" name="${2}"

  mkdir -p "${GLOBAL_DIR}"
  cp -a -- "${FAKE_SOURCES}/${source//\//_}/${name}" "${GLOBAL_DIR}/${name}"
  ln -s "../../.agents/skills/${name}" "${CLAUDE}/${name}"
  [[ -f "${GLOBAL_LOCK}" ]] || printf '{"version": 3, "skills": {}, "dismissed": {}}\n' >"${GLOBAL_LOCK}"
  node -e '
    const fs = require("node:fs");
    const [file, name, source] = process.argv.slice(1);
    const lock = JSON.parse(fs.readFileSync(file, "utf8"));
    lock.skills[name] = { source, sourceType: "github", sourceUrl: "https://github.com/" + source + ".git", skillPath: "skills/" + name + "/SKILL.md", skillFolderHash: "0".repeat(40) };
    fs.writeFileSync(file, JSON.stringify(lock, null, 2) + "\n");
  ' "${GLOBAL_LOCK}" "${name}" "${source}"
}

global_has() {
  node -e 'process.exit(require(process.argv[1]).skills[process.argv[2]] ? 0 : 1)' "${GLOBAL_LOCK}" "${1}"
}

make_source_skill test_gamma gamma
make_source_skill test_gamma gamma-extra
make_source_skill test_delta delta
make_source_skill test_epsilon epsilon

# Usage errors.
expect_status 2 --add
expect_output '--add needs --source'
expect_status 2 --check --source test/gamma
expect_status 2 --install --skill gamma
expect_status 2 --add --source test/gamma --skill ../escape

# An accidental global install is reported by --check and --list.
global_install test/gamma gamma
expect_status 0 --check
expect_output "'gamma' is installed globally with the skills CLI (from test/gamma)"
expect_status 1 --check --strict
expect_status 0 --list
[[ "${OUTPUT}" =~ gamma[[:space:]]+global[[:space:]]+test/gamma ]] || fail 'list does not show gamma as global'

# --add --dry-run and --add without confirmation change nothing.
lock_before="$(cat -- "${PROJECT}/skills-lock.json")"
expect_status 0 --add --source test/gamma --skill gamma --dry-run
expect_output "Would add 'gamma' from test/gamma"
expect_output "Would remove the global skills CLI install of 'gamma'"
expect_status 3 --add --source test/gamma --skill gamma
[[ "$(cat -- "${PROJECT}/skills-lock.json")" == "${lock_before}" ]] || fail 'add without confirmation changed the lockfile'
[[ -d "${GLOBAL_DIR}/gamma" && -L "${CLAUDE}/gamma" ]] || fail 'add without confirmation removed the global install'

# --add removes the global install first, then tracks and links the skill.
expect_status 0 --add --source test/gamma --skill gamma --yes
expect_output 'Removed 1 global skills CLI install(s)'
expect_output 'Added 1 skill(s)'
[[ ! -e "${GLOBAL_DIR}/gamma" ]] || fail 'add left the global skill directory'
! global_has gamma || fail 'add left the global lockfile entry'
[[ "$(readlink -- "${CLAUDE}/gamma")" == "${CANONICAL}/gamma" ]] || fail 'add did not link gamma for Claude'
[[ "$(readlink -- "${CODEX}/gamma")" == "${CANONICAL}/gamma" ]] || fail 'add did not link gamma for Codex'
[[ ! -e "${CANONICAL}/gamma-extra" ]] || fail 'add installed a skill that was not requested'
expect_status 0 --check

# Adding a tracked skill again is a no-op; a changed source is refused.
expect_status 0 --add --source test/gamma --skill gamma --yes
expect_output 'Nothing to do'
make_source_skill test_gamma gamma 2
lock_before="$(cat -- "${PROJECT}/skills-lock.json")"
expect_status 1 --add --source test/gamma --skill gamma --yes
expect_output "'gamma' is already tracked"
[[ "$(cat -- "${PROJECT}/skills-lock.json")" == "${lock_before}" ]] || fail 'a refused add changed the lockfile'
make_source_skill test_gamma gamma

# Unknown sources and skill names fail without changes.
expect_status 1 --add --source test/missing --yes
expect_output 'could not add test/missing'
expect_status 1 --add --source test/gamma --skill nope --yes
expect_output 'could not add test/gamma'

# --adopt refuses a global install whose name collides with an unmanaged
# link (here a skillz-style link) and changes nothing.
global_install test/delta delta
mkdir -p "${TMP_ROOT}/own/delta"
ln -s "${TMP_ROOT}/own/delta" "${CODEX}/delta"
lock_before="$(cat -- "${PROJECT}/skills-lock.json")"
expect_status 1 --adopt --yes
expect_output "Conflict: ${CODEX}/delta is an unmanaged link"
[[ "$(cat -- "${PROJECT}/skills-lock.json")" == "${lock_before}" ]] || fail 'a refused adopt changed the lockfile'
if [[ ! -d "${GLOBAL_DIR}/delta" || ! -L "${CLAUDE}/delta" ]] || ! global_has delta; then
  fail 'a refused adopt removed the global install'
fi
rm -- "${CODEX}/delta"

# A Claude entry that the skills CLI did not create is a conflict too:
# `skills remove -g` would delete it.
rm -- "${CLAUDE}/delta"
ln -s "${TMP_ROOT}/own/delta" "${CLAUDE}/delta"
expect_status 1 --adopt --skill delta --yes
expect_output "Conflict: ${CLAUDE}/delta is an unmanaged link"
[[ "$(readlink -- "${CLAUDE}/delta")" == "${TMP_ROOT}/own/delta" ]] || fail 'a refused adopt changed an unmanaged link'
rm -- "${CLAUDE}/delta"
ln -s ../../.agents/skills/delta "${CLAUDE}/delta"

# --adopt with --skill moves only that global install; unknown names fail.
global_install test/epsilon epsilon
expect_status 1 --adopt --skill nope --yes
expect_output "'nope' is not installed globally"
expect_status 0 --adopt --skill delta --yes
[[ "$(readlink -- "${CLAUDE}/delta")" == "${CANONICAL}/delta" ]] || fail 'adopt did not link delta'
! global_has delta || fail 'adopt left the global lockfile entry of delta'
global_has epsilon || fail 'adopt --skill delta also adopted epsilon'

# --adopt without --skill moves the remaining global installs.
expect_status 0 --adopt --yes
[[ "$(readlink -- "${CODEX}/epsilon")" == "${CANONICAL}/epsilon" ]] || fail 'adopt did not link epsilon'
[[ ! -e "${GLOBAL_DIR}/epsilon" ]] || fail 'adopt left the global copy of epsilon'
expect_status 0 --adopt --yes
expect_output 'Nothing to adopt'
expect_status 0 --check --strict

printf 'PASS: install-skills manager\n'
