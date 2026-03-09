#!/bin/bash

set -euo pipefail

node_run() {
  local script_path=""
  local node_version=""
  local working_directory=""
  local verbose="0"

  usage() {
    cat <<EOF
Usage: $(basename "$0") --script <file> [options]

Options:
  --script <file>         Node script to execute
  --node-version <ver>    Node version to use
                          Examples: 22, v22, 22.12.0, v22.12.0, lts/*, node
  --cwd <dir>             Working directory before execution
  --verbose               Enable verbose output
  --help                  Show this help message

Behaviour:
  * Simple versions such as 22 or 22.12.0 use a fast direct lookup.
  * Complex selectors such as lts/*, node, aliases, or .nvmrc use nvm.
EOF
  }

  log() {
    if [[ "${verbose}" == "1" ]]; then
      echo "${@}"
    fi
  }

  resolve_fast_node_path() {
    local requested_version="${1}"
    local nvm_versions_dir="${HOME}/.nvm/versions/node"
    local version_input=""
    local major_version=""
    local exact_version=""
    local candidate=""

    if [[ ! -d "${nvm_versions_dir}" ]]; then
      return 1
    fi

    version_input="${requested_version#v}"

    if [[ "${version_input}" =~ ^[0-9]+$ ]]; then
      major_version="${version_input}"

      candidate="$(
        find "${nvm_versions_dir}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' |
          sed 's/^v//' |
          grep -E "^${major_version}(\.|$)" |
          sort -V |
          tail -n 1
      )"

      if [[ -n "${candidate}" && -x "${nvm_versions_dir}/v${candidate}/bin/node" ]]; then
        echo "${nvm_versions_dir}/v${candidate}/bin/node"
        return 0
      fi

      return 1
    fi

    if [[ "${version_input}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      exact_version="${version_input}"

      if [[ -x "${nvm_versions_dir}/v${exact_version}/bin/node" ]]; then
        echo "${nvm_versions_dir}/v${exact_version}/bin/node"
        return 0
      fi

      return 1
    fi

    return 1
  }

  load_nvm() {
    export NVM_DIR="${HOME}/.nvm"

    if [[ ! -s "${NVM_DIR}/nvm.sh" ]]; then
      echo "Error: nvm.sh not found in ${NVM_DIR}" >&2
      return 1
    fi

    # shellcheck source=/dev/null
    source "${NVM_DIR}/nvm.sh"
  }

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --script)
      if [[ $# -lt 2 ]]; then
        echo "Error: --script requires a value." >&2
        usage
        return 1
      fi
      script_path="$2"
      shift 2
      ;;
    --node-version)
      if [[ $# -lt 2 ]]; then
        echo "Error: --node-version requires a value." >&2
        usage
        return 1
      fi
      node_version="$2"
      shift 2
      ;;
    --cwd)
      if [[ $# -lt 2 ]]; then
        echo "Error: --cwd requires a value." >&2
        usage
        return 1
      fi
      working_directory="$2"
      shift 2
      ;;
    --verbose)
      verbose="1"
      shift
      ;;
    --help)
      usage
      return 0
      ;;
    *)
      echo "Error: unknown option '${1}'." >&2
      usage
      return 1
      ;;
    esac
  done

  if [[ -z "${script_path}" ]]; then
    echo "Error: --script is required." >&2
    usage
    return 1
  fi

  if [[ ! -f "${script_path}" ]]; then
    echo "Error: script not found: ${script_path}" >&2
    usage
    return 1
  fi

  if [[ -n "${working_directory}" ]]; then
    if [[ ! -d "${working_directory}" ]]; then
      echo "Error: working directory not found: ${working_directory}" >&2
      usage
      return 1
    fi
    cd "${working_directory}"
  else
    cd "$(dirname "${script_path}")"
  fi

  local node_binary=""
  local used_strategy=""

  if [[ -n "${node_version}" ]]; then
    if node_binary="$(resolve_fast_node_path "${node_version}")"; then
      used_strategy="fast-path"
      log "Resolved node via fast path: ${node_binary}"
    else
      log "Fast path could not resolve '${node_version}', falling back to nvm."
      load_nvm
      nvm use "${node_version}" >/dev/null
      node_binary="$(command -v node)"
      used_strategy="nvm-use"
      log "Resolved node via nvm use: ${node_binary}"
    fi
  else
    if [[ -f ".nvmrc" ]]; then
      log "Found .nvmrc, using nvm."
      load_nvm
      nvm use >/dev/null
      node_binary="$(command -v node)"
      used_strategy="nvmrc"
      log "Resolved node via .nvmrc: ${node_binary}"
    else
      log "No version requested and no .nvmrc found, using nvm current/default."
      load_nvm
      node_binary="$(command -v node || true)"

      if [[ -z "${node_binary}" ]]; then
        nvm use default >/dev/null
        node_binary="$(command -v node)"
      fi

      used_strategy="nvm-default"
      log "Resolved node via nvm default/current: ${node_binary}"
    fi
  fi

  if [[ -z "${node_binary}" || ! -x "${node_binary}" ]]; then
    echo "Error: failed to resolve a usable node binary." >&2
    return 1
  fi

  log "Strategy: ${used_strategy}"
  log "Node version: $("${node_binary}" --version)"
  log "Script: ${script_path}"
  log "Working directory: $(pwd)"

  exec "${node_binary}" "${script_path}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  node_run "${@}"
fi
