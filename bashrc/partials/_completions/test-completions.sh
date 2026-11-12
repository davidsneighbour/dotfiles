#!/bin/bash
# shellcheck disable=SC2329,SC2034
# This file is run by tests only; the auto-source loader must skip it.
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then return 0; fi
set -euo pipefail
root=$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." >/dev/null && builtin pwd)
# shellcheck source=/dev/null
source "${root}/partials/_completions/_help_completion.sh"
work=$(mktemp -d)
trap 'rm -rf -- "${work}"' EXIT
export DNB_TEST_CALLS="${work}/calls"
fixture() {
  printf 'called\n' >>"${DNB_TEST_CALLS}"
  if [[ ${1-} == list ]]; then
    printf 'Options:\n  --child  Child flag\n'
  else
    printf 'Options:\n  -h, --help  Help\n  --output <file>  Output\nCommands:\n  list  List things\nExamples:\n  --bogus  Ignore this\n'
  fi
}
check() {
  COMP_WORDS=(fixture "${@}")
  COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
  _dnb_help_complete
}
check ''
[[ ${COMPREPLY[*]} == '-h --help --output list' ]]
check --h
[[ ${COMPREPLY[*]} == --help ]]
[[ $(wc -l <"${DNB_TEST_CALLS}") == 1 ]]
check list ''
[[ ${COMPREPLY[*]} == --child ]]
check --output list ''
[[ ${COMPREPLY[*]} == '-h --help --output list' ]]
check --output ''
[[ ${#COMPREPLY[@]} == 0 ]]
check -- ''
[[ ${#COMPREPLY[@]} == 0 ]]
dnb_completion_refresh
check ''
[[ $(wc -l <"${DNB_TEST_CALLS}") == 3 ]]
fixture() { printf 'Options:\n  --changed  Changed\n'; }
check ''
[[ ${COMPREPLY[*]} == --changed ]]
cat >"${work}/fixture" <<'SCRIPT'
#!/bin/bash
printf 'Options:\n  --external  External\n'
SCRIPT
chmod +x "${work}/fixture"
unset -f fixture
export PATH="${work}:${PATH}"
check ''
[[ ${COMPREPLY[*]} == --external ]]
printf '\nprintf "  --new  New\\n"\n' >>"${work}/fixture"
check ''
[[ ${COMPREPLY[*]} == '--external --new' ]]
# Failures are cached, and expiry permits a retry.
fixture() {
  printf 'called\n' >>"${DNB_TEST_CALLS}"
  return 1
}
dnb_completion_refresh
check ''
check ''
[[ ${#COMPREPLY[@]} == 0 ]]
[[ $(wc -l <"${DNB_TEST_CALLS}") == 4 ]]
_dnb_help_time['fixture ']=-300
check ''
[[ $(wc -l <"${DNB_TEST_CALLS}") == 5 ]]
unset -f fixture
printf '#!%s\n' "$(type -P node)" >"${work}/node-fixture"
cat >>"${work}/node-fixture" <<'SCRIPT'
if (process.argv[2] !== '--help') process.exit(1);
console.log('Options:\n  --node-option  Node option');
SCRIPT
chmod +x "${work}/node-fixture"
COMP_WORDS=(node-fixture --n)
COMP_CWORD=1
_dnb_help_complete
[[ ${COMPREPLY[*]} == --node-option ]]
# Exercise the real loader without starting unrelated external integrations.
# shellcheck source=/dev/null
source "${root}/lib/00-core/dnb-core-source.bash"
# shellcheck source=/dev/null
source "${root}/partials/_functions/searchfor.bash"
while IFS= read -r line; do
  [[ ${line} == '# codex completion' ]] && break
  printf '%s\n' "${line}"
done <"${root}/partials/completions" >"${work}/loader"
BASHRC_PATH="${root}"
# shellcheck source=/dev/null
source "${work}/loader"
[[ $(complete -p searchfor) == *'_dnb_help_complete'* ]]
COMP_WORDS=(searchfor --l)
COMP_CWORD=1
_dnb_help_complete
[[ ${COMPREPLY[*]} == --locations-only ]]
printf 'Completion tests passed\n'
