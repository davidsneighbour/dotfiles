#!/bin/bash
# Maintain the machine-local runtime; only --update uses the network.
set -eo pipefail

print_help() {
  printf '%s\n' 'Usage: node-cron.sh --refresh|--update [--verbose] [--exec -- NODE_ARGUMENTS...]' \
    'Refresh ~/.local/bin/node-cron without network access or installation.' \
    '--update checks published LTS releases, installs the latest, and refreshes the link.' \
    '--exec runs the refreshed runtime with the arguments after --.'
}
fail() {
  printf 'node-cron: %s\n' "${*}" >&2
  exit 1
}
refresh=false
update=false
execute=false
verbose=false
while (($#)); do
  case "${1}" in
    --help) print_help; exit 0 ;;
    --refresh) refresh=true ;;
    --update) update=true ;;
    --verbose) verbose=true ;;
    --exec) execute=true ;;
    --) shift; break ;;
    *) print_help >&2; fail "Unknown option: ${1}" ;;
  esac
  shift
done
if [[ "${refresh}" == true && "${update}" == true ]]; then
  fail 'Choose either --refresh or --update.'
fi
if [[ "${refresh}" != true && "${update}" != true ]]; then
  print_help
  exit 1
fi
export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
[[ -s "${NVM_DIR}/nvm.sh" ]] || fail "Missing ${NVM_DIR}/nvm.sh. Install NVM first."
# NVM is third-party shell code and does not support nounset.
# shellcheck source=/dev/null
source "${NVM_DIR}/nvm.sh" --no-use || fail 'Could not load nvm.sh.'
command -v nvm >/dev/null || fail 'nvm.sh did not define nvm.'
runtime_dir="${HOME}/.local/bin"
[[ ! -e "${runtime_dir}/node-cron" || -L "${runtime_dir}/node-cron" ]] || fail 'Refusing to replace a non-symlink node-cron.'
mkdir -p "${HOME}/.logs/node-runtime"
log_file="${HOME}/.logs/node-runtime/$(date +%Y%m%d-%H%M%S).log"
node_binary=''
if [[ "${update}" == true ]]; then
  printf 'Checking the latest published LTS release. Log: %s\n' "${log_file}"
  if ! latest_version="$(nvm version-remote --lts 2>>"${log_file}")" || [[ ! "${latest_version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "Could not resolve the latest published LTS release. See ${log_file}"
  fi
  printf 'Installing LTS %s if needed.\n' "${latest_version}"
  if ! nvm install "${latest_version}" >>"${log_file}" 2>&1; then
    fail "LTS installation failed; the existing link is unchanged. See ${log_file}"
  fi
  node_binary="$(nvm which "${latest_version}" 2>>"${log_file}")" || fail "Could not resolve installed ${latest_version}. See ${log_file}"
else
  # The lts/* alias can point to a patch that is not installed. Resolve installed
  # versions of cached LTS majors as well, without consulting the network.
  candidates=()
  if node_binary="$(nvm which 'lts/*' 2>/dev/null)"; then
    candidates+=("${node_binary}")
  fi
  for alias_file in "${NVM_DIR}"/alias/lts/*; do
    [[ -f "${alias_file}" ]] || continue
    IFS= read -r alias_version <"${alias_file}" || continue
    [[ "${alias_version}" =~ ^v([0-9]+)\. ]] || continue
    if node_binary="$(nvm which "${BASH_REMATCH[1]}" 2>/dev/null)"; then
      candidates+=("${node_binary}")
    fi
  done
  ((${#candidates[@]})) || fail 'No installed LTS Node found. Run node-cron.sh --update.'
  node_binary="$(printf '%s\n' "${candidates[@]}" | sort -V | tail -n 1)"
fi
[[ "${node_binary}" == /* && -f "${node_binary}" && -x "${node_binary}" ]] || fail "Invalid Node executable: ${node_binary}"
mkdir -p "${runtime_dir}"
[[ ! -e "${runtime_dir}/node-cron" || -L "${runtime_dir}/node-cron" ]] || fail 'Refusing to replace a non-symlink node-cron.'
temporary_dir="$(mktemp -d "${runtime_dir}/.node-cron.XXXXXX")"
trap 'rm -rf -- "${temporary_dir}"' EXIT
ln -s -- "${node_binary}" "${temporary_dir}/node-cron"
mv -Tf -- "${temporary_dir}/node-cron" "${runtime_dir}/node-cron"
printf 'node-cron -> %s\n' "${node_binary}" >>"${log_file}"
if [[ "${execute}" != true || "${verbose}" == true ]]; then
  printf 'node-cron -> %s\n' "${node_binary}"
fi
if [[ "${execute}" == true ]]; then
  rmdir -- "${temporary_dir}"
  trap - EXIT
  exec "${runtime_dir}/node-cron" "$@"
fi
