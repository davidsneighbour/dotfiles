#!/bin/bash
# shellcheck shell=bash

searchfor() {
  local term=""
  local path="${HOME}/github.com/davidsneighbour"
  local locations_only=0

  # help
  if [[ $# -eq 0 ]]; then
    echo "Usage: ${FUNCNAME[0]} <SEARCHTERM> [--path <path>] [--locations-only] [--help]"
    echo
    echo "Options:"
    echo "  --path <path>      Override search base path (default: ${HOME}/github.com/davidsneighbour)"
    echo "  --locations-only   Show only file:line of each match, not the matched code"
    echo "  --help             Show this help message"
    return 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --path)
      path="$2"
      shift 2
      ;;
    --locations-only)
      locations_only=1
      shift
      ;;
    --help)
      echo "Usage: ${FUNCNAME[0]} <SEARCHTERM> [--path <path>] [--locations-only] [--help]"
      return 0
      ;;
    *)
      if [[ -z "${term}" ]]; then
        term="$1"
      else
        echo "[ERROR] Unexpected argument: $1"
        return 1
      fi
      shift
      ;;
    esac
  done

  if [[ -z "${term}" ]]; then
    echo "[ERROR] Missing SEARCHTERM"
    return 1
  fi

  if [[ ! -d "${path}" ]]; then
    echo "[ERROR] Path does not exist: ${path}"
    return 1
  fi

  if [[ "${locations_only}" -eq 1 ]]; then
    grep -rIn \
      --exclude-dir='.git' \
      --exclude-dir='node_modules' \
      --exclude-dir='scratch' \
      --exclude-dir='chatgpt-obsidian-importer' \
      --exclude='*/.config/Code/*' \
      "${term}" \
      "${path}" | cut -d: -f1,2
  else
    grep -rIn \
      --exclude-dir='.git' \
      --exclude-dir='node_modules' \
      --exclude-dir='scratch' \
      --exclude-dir='chatgpt-obsidian-importer' \
      --exclude='*/.config/Code/*' \
      --color=always \
      "${term}" \
      "${path}"
  fi
}
