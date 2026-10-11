#!/bin/bash
#
# The AI tool config files that live in the protected repository are still
# symlinks: ~/.claude/settings.json and ~/.codex/config.toml. Claude Code and
# Codex can replace a symlink with a regular file when they save settings;
# after that, changes no longer reach the repository.
#
# Exit status:
#   0  all links point into the protected repository
#   1  a link is missing or points elsewhere (running "dotfiles ai" fixes it)
#   3  a regular file replaced a link; Dotbot would overwrite it (force: true),
#      so the "dotfiles" helper refuses to run until it is merged by hand

# Checks run through system-checkup, which exports SYSTEM_CHECKUP_DIR.
: "${SYSTEM_CHECKUP_DIR:?run this check with: system-checkup --check <name>}"

REPO_ROOT="$(cd -- "${SYSTEM_CHECKUP_DIR}/../.." && pwd -P)"
PROTECTED_ROOT="${REPO_ROOT}/protected/ai-configs"

# Link, then the path below protected/ai-configs it must resolve to. The links
# come from configs/dotbot/config.ai.yaml.
EXPECTED_LINKS=(
  "${HOME}/.claude/settings.json:claude/settings.json"
  "${HOME}/.codex/config.toml:codex/config.toml"
)

rc=0
for entry in "${EXPECTED_LINKS[@]}"; do
  link="${entry%%:*}"
  target="${PROTECTED_ROOT}/${entry#*:}"
  display="${link/#"${HOME}"/\~}"
  if [[ -e "${link}" && ! -L "${link}" ]]; then
    printf '%s is a regular file, expected a link to %s\n' "${display}" "${target}"
    rc=3
  elif [[ ! -L "${link}" ]]; then
    printf '%s does not exist\n' "${display}"
    [[ "${rc}" -eq 0 ]] && rc=1
  elif [[ "$(readlink -f -- "${link}")" != "$(readlink -f -- "${target}")" ]]; then
    printf '%s points to %s, expected %s\n' "${display}" "$(readlink -- "${link}")" "${target}"
    [[ "${rc}" -eq 0 ]] && rc=1
  fi
done

if [[ "${rc}" -eq 3 ]]; then
  printf 'Fix: merge the regular file into the repository copy (diff <file> <repository file>), then delete it and run "dotfiles ai"\n'
elif [[ "${rc}" -ne 0 ]]; then
  printf 'Fix: run "dotfiles ai" to restore the links\n'
else
  printf 'All %s AI config links point into %s\n' "${#EXPECTED_LINKS[@]}" "${PROTECTED_ROOT/#"${HOME}"/\~}"
fi
exit "${rc}"
