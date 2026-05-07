#!/bin/bash

set -Eeuo pipefail

print_help() {
  cat <<EOF_HELP
Usage: $(basename "$0") [--help] [--dotfiles-root <path>]

Install local VS Code extensions from this dotfiles repository.

Creates a symlink from:
  <dotfiles-root>/configs/vscode/extensions/dnb-dotfiles-tools

to:
  ~/.vscode/extensions/davidsneighbour.dnb-dotfiles-tools

Options:
  --help                  Show this help message.
  --dotfiles-root <path>  Repository root. Defaults to ~/github.com/davidsneighbour/dotfiles.

Examples:
  $(basename "$0")
  $(basename "$0") --dotfiles-root "${HOME}/github.com/davidsneighbour/dotfiles"

Requirements:
  * VS Code installed for the current user.
  * The local extension dependencies installed and built via npm.
EOF_HELP
}

fail() {
  local message="${1:-Unknown error.}"

  echo "[error] ${message}" >&2
  print_help >&2
  exit 1
}

install_local_extension() {
  local dotfiles_root="${1}"
  local source_dir="${dotfiles_root}/configs/vscode/extensions/dnb-dotfiles-tools"
  local target_dir="${HOME}/.vscode/extensions/davidsneighbour.dnb-dotfiles-tools"

  if [[ ! -d "${source_dir}" ]]; then
    fail "Missing extension source directory: ${source_dir}"
  fi

  if [[ ! -f "${source_dir}/package.json" ]]; then
    fail "Missing extension manifest: ${source_dir}/package.json"
  fi

  if [[ ! -f "${source_dir}/out/extension.js" ]]; then
    fail "Missing compiled extension: ${source_dir}/out/extension.js. Run npm install && npm run build in ${source_dir}."
  fi

  mkdir -p "${HOME}/.vscode/extensions"

  if [[ -e "${target_dir}" && ! -L "${target_dir}" ]]; then
    fail "Target exists and is not a symlink: ${target_dir}"
  fi

  ln -sfn "${source_dir}" "${target_dir}"

  echo "[ok] Linked local VS Code extension: ${target_dir} -> ${source_dir}"
}

main() {
  local dotfiles_root="${HOME}/github.com/davidsneighbour/dotfiles"

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --help)
        print_help
        exit 0
        ;;
      --dotfiles-root)
        if [[ -z "${2:-}" ]]; then
          fail "Missing value for --dotfiles-root."
        fi
        dotfiles_root="${2}"
        shift 2
        ;;
      *)
        fail "Unknown parameter: ${1}"
        ;;
    esac
  done

  install_local_extension "${dotfiles_root}"
}

main "$@"
