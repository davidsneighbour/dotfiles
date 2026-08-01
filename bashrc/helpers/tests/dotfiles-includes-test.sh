#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_HELPER="$(readlink -f "${SCRIPT_DIR}/../dotfiles")"

# shellcheck disable=SC1090
source "${DOTFILES_HELPER}"

dnb_log() {
  :
}

fail() {
  printf 'FAIL: %s\n' "${1}" >&2
  exit 1
}

assert_equal() {
  local expected="${1}"
  local actual="${2}"
  local message="${3}"

  if [[ "${expected}" != "${actual}" ]]; then
    printf 'FAIL: %s\n' "${message}" >&2
    printf 'Expected: %s\n' "${expected}" >&2
    printf 'Actual:   %s\n' "${actual}" >&2
    exit 1
  fi
}

assert_array_equal() {
  local expected_name="${1}"
  local actual_name="${2}"
  local message="${3}"
  local -n expected_ref="${expected_name}"
  local -n actual_ref="${actual_name}"
  local index

  if [[ "${#expected_ref[@]}" -ne "${#actual_ref[@]}" ]]; then
    printf 'FAIL: %s\n' "${message}" >&2
    printf 'Expected %s items, got %s items.\n' "${#expected_ref[@]}" "${#actual_ref[@]}" >&2
    printf 'Expected: %s\n' "${expected_ref[*]}" >&2
    printf 'Actual:   %s\n' "${actual_ref[*]}" >&2
    exit 1
  fi

  for index in "${!expected_ref[@]}"; do
    assert_equal "${expected_ref[${index}]}" "${actual_ref[${index}]}" "${message} at index ${index}"
  done
}

write_file() {
  local file_path="${1}"
  local content="${2}"

  printf '%s' "${content}" >"${file_path}"
}

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

CONFIGS_DIR="${TMPDIR}/configs/dotbot"
INCLUDES_FILE="${CONFIGS_DIR}/includes.yaml"
DOTBOT_TEST_CAPTURE="${TMPDIR}/dotbot.args"
export DOTBOT_TEST_CAPTURE
unset DNB_VERBOSE

mkdir -p "${CONFIGS_DIR}" "${TMPDIR}/bin" "${TMPDIR}/external"

write_file "${TMPDIR}/bin/dotbot" "#!/bin/bash
printf '%s\n' \"\$@\" >\"\${DOTBOT_TEST_CAPTURE}\"
"
chmod +x "${TMPDIR}/bin/dotbot"
PATH="${TMPDIR}/bin:${PATH}"

write_file "${CONFIGS_DIR}/config.host-locutus.yaml" '---
'
write_file "${CONFIGS_DIR}/config.ai.yaml" '---
'
write_file "${CONFIGS_DIR}/config.short.yaml" '---
'
write_file "${TMPDIR}/external/config.project.yaml" '---
'

write_file "${INCLUDES_FILE}" "---
config.host-locutus.yaml:
  - config.ai.yaml
  - ${TMPDIR}/external/config.project.yaml
"

run_dotbot_with_config "${CONFIGS_DIR}/config.host-locutus.yaml"

# shellcheck disable=SC2034
mapfile -t actual_dotbot_args <"${DOTBOT_TEST_CAPTURE}"
# shellcheck disable=SC2034
# shellcheck disable=SC2154
expected_dotbot_args=(
  '--base-directory'
  "${REPO_ROOT}"
  '--config-file'
  "${CONFIGS_DIR}/config.host-locutus.yaml"
  "${CONFIGS_DIR}/config.ai.yaml"
  "${TMPDIR}/external/config.project.yaml"
  '--force-color'
  '--quiet'
  '--exit-on-failure'
)
# shellcheck disable=SC2034
assert_array_equal expected_dotbot_args actual_dotbot_args 'dotbot receives primary and included configs in order'

write_file "${INCLUDES_FILE}" '---
host-locutus:
  - config.short.yaml
'
resolved_paths=()
resolve_included_config_paths "${CONFIGS_DIR}/config.host-locutus.yaml" resolved_paths
# shellcheck disable=SC2034
expected_paths=("${CONFIGS_DIR}/config.short.yaml")
assert_array_equal expected_paths resolved_paths 'short include keys resolve to canonical config filenames'

write_file "${INCLUDES_FILE}" '---
config.ai.yaml:
  - config.short.yaml
'
resolved_paths=()
resolve_included_config_paths "${CONFIGS_DIR}/config.host-locutus.yaml" resolved_paths
assert_equal '0' "${#resolved_paths[@]}" 'unmatched include keys do not add configs'

write_file "${INCLUDES_FILE}" '---
config.host-locutus.yaml:
  - missing.yaml
'
resolved_paths=()
if resolve_included_config_paths "${CONFIGS_DIR}/config.host-locutus.yaml" resolved_paths; then
  fail 'missing included configs must fail'
fi

printf 'PASS: dotfiles include resolution\n'
