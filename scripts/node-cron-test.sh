#!/bin/bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "${test_dir}"' EXIT
export HOME="${test_dir}"
export NVM_DIR="${test_dir}/nvm"
mkdir -p "${NVM_DIR}/alias/lts" "${NVM_DIR}/versions/node/v24.1.0/bin"
printf 'v24.9.0\n' >"${NVM_DIR}/alias/lts/example"
cat >"${NVM_DIR}/versions/node/v24.1.0/bin/node" <<'NODE'
#!/bin/bash
printf 'fake-node:%s\n' "${*}"
NODE
chmod +x "${NVM_DIR}/versions/node/v24.1.0/bin/node"
cat >"${NVM_DIR}/nvm.sh" <<'NVM'
nvm() {
  [[ "${1}" == which && "${2}" == 24 ]] || return 1
  printf '%s/versions/node/v24.1.0/bin/node\n' "${NVM_DIR}"
}
NVM
/bin/bash "${script_dir}/node-cron.sh" --refresh
[[ "$(readlink -f "${HOME}/.local/bin/node-cron")" == "${NVM_DIR}/versions/node/v24.1.0/bin/node" ]]
[[ "$(/bin/bash "${script_dir}/node-cron.sh" --refresh --exec -- --version)" == 'fake-node:--version' ]]
/bin/bash "${script_dir}/node-cron.sh" --refresh &
first_pid=$!
/bin/bash "${script_dir}/node-cron.sh" --refresh &
second_pid=$!
wait "${first_pid}" "${second_pid}"
# An update must use the remote result, install it, and select that exact version.
cp "${NVM_DIR}/nvm.sh" "${NVM_DIR}/offline.sh"
cat >"${NVM_DIR}/nvm.sh" <<'NVM'
nvm() {
  case "${1}" in
    version-remote)
      [[ "${2}" == --lts ]] || return 1
      [[ ! -e "${NVM_DIR}/fail-remote" ]] || return 1
      printf 'v26.2.0\n'
      ;;
    install)
      [[ "${2}" == v26.2.0 ]] || return 1
      [[ ! -e "${NVM_DIR}/fail-install" ]] || return 1
      mkdir -p "${NVM_DIR}/versions/node/v26.2.0/bin"
      cp "${NVM_DIR}/versions/node/v24.1.0/bin/node" "${NVM_DIR}/versions/node/v26.2.0/bin/node"
      ;;
    which)
      [[ "${2}" == v26.2.0 ]] || return 1
      printf '%s/versions/node/v26.2.0/bin/node\n' "${NVM_DIR}"
      ;;
    *) return 1 ;;
  esac
}
NVM
/bin/bash "${script_dir}/node-cron.sh" --update
updated_target="$(readlink "${HOME}/.local/bin/node-cron")"
[[ "${updated_target}" == "${NVM_DIR}/versions/node/v26.2.0/bin/node" ]]
for failure in fail-remote fail-install; do
  touch "${NVM_DIR}/${failure}"
  if /bin/bash "${script_dir}/node-cron.sh" --update; then exit 1; fi
  [[ "$(readlink "${HOME}/.local/bin/node-cron")" == "${updated_target}" ]]
  rm "${NVM_DIR}/${failure}"
done
if /bin/bash "${script_dir}/node-cron.sh" --refresh --update; then exit 1; fi
mv "${NVM_DIR}/offline.sh" "${NVM_DIR}/nvm.sh"
rm "${HOME}/.local/bin/node-cron"
printf 'preserve\n' >"${HOME}/.local/bin/node-cron"
if /bin/bash "${script_dir}/node-cron.sh" --refresh; then exit 1; fi
[[ "$(cat "${HOME}/.local/bin/node-cron")" == preserve ]]
rm "${HOME}/.local/bin/node-cron"
chmod -x "${NVM_DIR}/versions/node/v24.1.0/bin/node"
if /bin/bash "${script_dir}/node-cron.sh" --refresh; then exit 1; fi
rm "${NVM_DIR}/alias/lts/example"
if /bin/bash "${script_dir}/node-cron.sh" --refresh; then exit 1; fi
printf 'return 1\n' >"${NVM_DIR}/nvm.sh"
if /bin/bash "${script_dir}/node-cron.sh" --refresh; then exit 1; fi
rm "${NVM_DIR}/nvm.sh"
if /bin/bash "${script_dir}/node-cron.sh" --refresh; then exit 1; fi
printf 'Node cron tests passed.\n'
