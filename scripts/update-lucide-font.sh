#!/bin/bash

set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly REPOSITORY='lucide-icons/lucide'
readonly RELEASE_API_URL="https://api.github.com/repos/${REPOSITORY}/releases/latest"
readonly COMMIT_MESSAGE='chore(fonts): update Lucide icon font'

usage() {
  cat <<USAGE
Usage:
  ${SCRIPT_NAME} [--check] [--force] [--no-commit] [--verbose]

Update the Lucide icon font in configs/fonts/System/lucide to the latest
GitHub release of ${REPOSITORY}.

The installed version is read from configs/fonts/System/lucide/VERSION.
If a newer release exists, the script downloads lucide-font-<version>.zip,
replaces the folder contents, writes the new VERSION file, refreshes the
font cache, and commits only that folder (without commit hooks) with:

  ${COMMIT_MESSAGE}

Options:
  --check      Only report the installed and the latest version.
  --force      Install the latest release even if it is not newer.
  --no-commit  Update the files, but do not create a commit.
  --verbose    Print each step.
  --help       Show this help output.

Examples:
  ${SCRIPT_NAME} --check
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --no-commit --verbose
USAGE
}

fail() {
  printf 'Error: %s\n' "${1}" >&2
  exit 1
}

verbose_mode='false'

log_verbose() {
  if [[ "${verbose_mode}" == 'true' ]]; then
    printf '%s\n' "${1}"
  fi
}

require_command() {
  local command_name="${1}"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    fail "Required command is not available: ${command_name}"
  fi
}

is_valid_version() {
  [[ "${1}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Return 0 if the first version is newer than the second version.
is_newer_version() {
  local candidate="${1}"
  local installed="${2}"

  [[ "${candidate}" != "${installed}" ]] &&
    [[ "$(printf '%s\n%s\n' "${candidate}" "${installed}" | sort -V | tail -n 1)" == "${candidate}" ]]
}

# Print a warning for each icon that was removed or that moved to another
# codepoint. Configuration files reference icons by codepoint (for example
# ""), so these icons can show the wrong glyph after the update.
report_codepoint_changes() {
  local old_file="${1}"
  local new_file="${2}"
  local changes

  if [[ ! -f "${old_file}" ]]; then
    log_verbose 'No installed codepoints.json found, skipping codepoint comparison.'
    return 0
  fi

  changes="$(jq -r --slurpfile new "${new_file}" '
    to_entries[]
    | select($new[0][.key] != .value)
    | if $new[0][.key] == null
      then "  removed: \(.key) (\(.value))"
      else "  changed: \(.key) (\(.value) -> \($new[0][.key]))"
      end
  ' "${old_file}")"

  if [[ -n "${changes}" ]]; then
    printf 'Warning: icons were removed or changed codepoints (decimal values):\n%s\n' "${changes}" >&2
    printf 'Check configuration files that use these icons.\n' >&2
  else
    log_verbose 'No existing icon was removed or changed its codepoint.'
  fi
}

check_only='false'
force_update='false'
create_commit='true'

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    --check)
      check_only='true'
      ;;
    --force)
      force_update='true'
      ;;
    --no-commit)
      create_commit='false'
      ;;
    --verbose)
      verbose_mode='true'
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      printf 'Error: Unknown option: %s\n\n' "${1}" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

for command_name in curl git jq unzip sort; do
  require_command "${command_name}"
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "${script_dir}" rev-parse --show-toplevel)" ||
  fail "Cannot find the repository root from ${script_dir}."
readonly relative_font_dir='configs/fonts/System/lucide'
readonly font_dir="${repo_root}/${relative_font_dir}"
readonly version_file="${font_dir}/VERSION"

installed_version=''
if [[ -f "${version_file}" ]]; then
  installed_version="$(tr -d '[:space:]' <"${version_file}")"
  if ! is_valid_version "${installed_version}"; then
    fail "Invalid version in ${version_file}: '${installed_version}'"
  fi
fi

log_verbose "Requesting latest release from ${RELEASE_API_URL}"
release_json="$(curl --fail --silent --show-error --location \
  --header 'Accept: application/vnd.github+json' \
  "${RELEASE_API_URL}")" ||
  fail "Cannot get the latest release from ${RELEASE_API_URL}. Check the network connection or the GitHub API rate limit."

latest_version="$(jq -r '.tag_name // empty' <<<"${release_json}")"
if ! is_valid_version "${latest_version}"; then
  fail "Unexpected release tag from GitHub: '${latest_version}'"
fi

printf 'Installed version: %s\n' "${installed_version:-unknown}"
printf 'Latest version:    %s\n' "${latest_version}"

update_available='true'
if [[ -n "${installed_version}" ]] && ! is_newer_version "${latest_version}" "${installed_version}"; then
  update_available='false'
fi

if [[ "${check_only}" == 'true' ]]; then
  if [[ "${update_available}" == 'true' ]]; then
    printf 'An update is available.\n'
  else
    printf 'Lucide is up to date.\n'
  fi
  exit 0
fi

if [[ "${update_available}" == 'false' && "${force_update}" == 'false' ]]; then
  printf 'Lucide is up to date. Use --force to install the release again.\n'
  exit 0
fi

if [[ -n "$(git -C "${repo_root}" status --porcelain -- "${relative_font_dir}")" ]]; then
  fail "${relative_font_dir} has uncommitted changes. Commit or discard them first."
fi

asset_name="lucide-font-${latest_version}.zip"
asset_url="$(jq -r --arg name "${asset_name}" \
  '.assets[] | select(.name == $name) | .browser_download_url' <<<"${release_json}")"
if [[ -z "${asset_url}" ]]; then
  fail "Release ${latest_version} has no asset named ${asset_name}."
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

log_verbose "Downloading ${asset_url}"
curl --fail --silent --show-error --location --output "${work_dir}/${asset_name}" "${asset_url}" ||
  fail "Cannot download ${asset_url}."

log_verbose "Extracting ${asset_name}"
unzip -q "${work_dir}/${asset_name}" -d "${work_dir}/extract" ||
  fail "Cannot extract ${asset_name}."

readonly extracted_dir="${work_dir}/extract/lucide-font"
for required_file in lucide.ttf codepoints.json; do
  if [[ ! -f "${extracted_dir}/${required_file}" ]]; then
    fail "The archive layout changed: lucide-font/${required_file} is missing. Check ${asset_url} manually."
  fi
done

report_codepoint_changes "${font_dir}/codepoints.json" "${extracted_dir}/codepoints.json"

log_verbose "Replacing the contents of ${relative_font_dir}"
mkdir -p "${font_dir}"
find "${font_dir}" -mindepth 1 -delete
cp -a "${extracted_dir}/." "${font_dir}/"
printf '%s\n' "${latest_version}" >"${version_file}"

if command -v fc-cache >/dev/null 2>&1; then
  log_verbose 'Refreshing the font cache'
  fc-cache -f >/dev/null || printf 'Warning: fc-cache failed. Run "fc-cache -f" manually.\n' >&2
fi

printf 'Updated Lucide to %s.\n' "${latest_version}"

if [[ "${create_commit}" == 'false' ]]; then
  printf 'Skipping the commit (--no-commit).\n'
  exit 0
fi

git -C "${repo_root}" add --all -- "${relative_font_dir}"
if git -C "${repo_root}" diff --cached --quiet -- "${relative_font_dir}"; then
  printf 'No file changes to commit.\n'
  exit 0
fi

# Commit only the font folder. Other staged changes stay staged.
# --no-verify skips the commit hooks: the files are upstream release files
# that do not follow this repository's lint rules, and hooks such as
# stylelint --fix would change them.
git -C "${repo_root}" commit --no-verify --message "${COMMIT_MESSAGE}" -- "${relative_font_dir}"
printf 'Committed: %s\n' "${COMMIT_MESSAGE}"
