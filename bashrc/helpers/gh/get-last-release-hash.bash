#!/bin/bash
# shellcheck shell=bash

set -euo pipefail

show_help() {
  local command_name
  command_name="$(basename "$0")"

  cat <<EOF
Usage:
  ${command_name} --repo OWNER/REPO
  ${command_name} --verbose --repo OWNER/REPO
  ${command_name} OWNER/REPO

Description:
  Prints the commit hash behind the latest full GitHub release of a repository.

  By default, the script prints only the hash.
  With --verbose, the script prints a JSON object with the hash, release tag, and release URL.

Examples:
  ${command_name} --repo actions/checkout
  ${command_name} --verbose --repo actions/checkout
  ${command_name} actions/checkout

Options:
  --repo OWNER/REPO  GitHub repository, for example actions/checkout.
  --verbose          Print JSON output instead of only the hash.
  --help             Show this help message.

Requirements:
  gh                 GitHub CLI, authenticated for API access.
EOF
}

fail() {
  printf 'Error: %s\n\n' "$1" >&2
  show_help >&2
  exit 1
}

require_command() {
  local command_name="${1}"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    fail "Required command not found: ${command_name}"
  fi
}

json_escape() {
  local value="${1}"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"

  printf '%s' "${value}"
}

get_latest_release_tag() {
  local repo="${1}"

  gh release list \
    --repo "${repo}" \
    --exclude-drafts \
    --exclude-pre-releases \
    --limit 1 \
    --order desc \
    --json tagName \
    --jq '.[0].tagName'
}

get_release_url() {
  local repo="${1}"
  local tag="${2}"

  gh api \
    "repos/${repo}/releases/tags/${tag}" \
    --jq '.html_url'
}

get_commit_hash_for_tag() {
  local repo="${1}"
  local tag="${2}"
  local ref_data
  local object_type
  local object_sha

  ref_data="$(
    gh api \
      "repos/${repo}/git/ref/tags/${tag}" \
      --jq '.object.type + " " + .object.sha'
  )"

  read -r object_type object_sha <<<"${ref_data}"

  case "${object_type}" in
  commit)
    printf '%s\n' "${object_sha}"
    ;;
  tag)
    gh api \
      "repos/${repo}/git/tags/${object_sha}" \
      --jq '.object.sha'
    ;;
  *)
    fail "Unsupported tag object type for ${repo}@${tag}: ${object_type}"
    ;;
  esac
}

print_verbose_json() {
  local hash="${1}"
  local tag="${2}"
  local release_url="${3}"

  cat <<EOF
{
  "hash": "$(json_escape "${hash}")",
  "tag": "$(json_escape "${tag}")",
  "releaseUrl": "$(json_escape "${release_url}")"
}
EOF
}

main() {
  local repo=""
  local verbose="false"

  require_command "gh"

  while [ "${#}" -gt 0 ]; do
    case "${1}" in
    --repo)
      shift
      [ "${#}" -gt 0 ] || fail "Missing value for --repo."
      repo="${1}"
      ;;
    --verbose)
      verbose="true"
      ;;
    --help | -h)
      show_help
      exit 0
      ;;
    -*)
      fail "Unknown option: ${1}"
      ;;
    *)
      if [ -n "${repo}" ]; then
        fail "Repository was provided more than once."
      fi
      repo="${1}"
      ;;
    esac
    shift
  done

  [ -n "${repo}" ] || fail "Missing repository."
  [[ "${repo}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "Repository must use OWNER/REPO format."

  local tag
  local hash
  local release_url

  tag="$(get_latest_release_tag "${repo}")"

  [ -n "${tag}" ] || fail "No full release found for ${repo}."

  hash="$(get_commit_hash_for_tag "${repo}" "${tag}")"

  if [ "${verbose}" = "true" ]; then
    release_url="$(get_release_url "${repo}" "${tag}")"
    print_verbose_json "${hash}" "${tag}" "${release_url}"
    exit 0
  fi

  printf '%s\n' "${hash}"
}

main "$@"
