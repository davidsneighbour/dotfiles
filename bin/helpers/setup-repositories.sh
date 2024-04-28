#!/bin/bash

usage() {
  echo "Usage: $0 [--output-dir OUTPUT_DIR] [--debug]"
  echo "  --output-dir  Directory where repositories will be cloned (optional, default is current directory)."
  echo "  --debug       Enables debug mode which saves API responses as JSON files."
  exit 1
}

check_dependencies() {
  for cmd in curl jq git; do
    command -v "${cmd}" >/dev/null 2>&1 || {
      echo >&2 "The script requires ${cmd} but it's not installed. Aborting."
      exit 1
    }
  done
}

parse_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
    --output-dir)
      output_dir="${2%/}"
      shift
      ;;
    --debug)
      debug_mode="true"
      ;;
    *)
      echo "Unknown parameter passed: $1"
      usage
      ;;
    esac
    shift
  done
}

initialize() {
  if [ -z "${output_dir}" ]; then
    output_dir="."
  fi
  mkdir -p "${output_dir}" || exit
  cd "${output_dir}" || exit

  if [ -f ~/.env ]; then
    # shellcheck source=/dev/null
    source ~/.env
  else
    echo "Error: .env file not found in home directory."
    exit 2
  fi

  if [ -z "${GITHUB_DEV_TOKEN}" ]; then
    echo "Error: GitHub development token not set in .env file."
    exit 3
  fi
}

fetch_and_clone_repos() {
  local page=1 all_repos_fetched=false response repo_count
  while [ "${all_repos_fetched}" = false ]; do
    response=$(curl -sH "Authorization: token ${GITHUB_DEV_TOKEN}" "https://api.github.com/user/repos?type=all&per_page=100&page=${page}")
    if ! echo "${response}" | jq . >/dev/null 2>&1; then
      echo "Failed to parse JSON, or got an error from GitHub:"
      echo "${response}"
      exit 4
    fi

    if [ "${debug_mode}" = "true" ]; then
      echo "${response}" >"debug_response_page_${page}.json"
    fi

    repo_count=$(echo "${response}" | jq -r '. | length')
    if [ "${repo_count}" -eq 0 ]; then
      all_repos_fetched=true
      echo "No more repositories to clone."
      break
    fi

    clone_repositories "${response}"
    ((page++))
  done
}

clone_repositories() {
  echo "$1" | jq -r '.[] | .name, .ssh_url' | while
    read -r repo_name
    read -r ssh_url
  do
    if [ -z "${ssh_url}" ]; then
      echo "A repository without a clone URL was encountered: ${repo_name}"
      continue
    fi
    if [ -d "${output_dir}/${repo_name}" ]; then
      echo "Directory ${output_dir}/${repo_name} already exists, skipping clone."
      continue
    fi
    echo "Cloning ${ssh_url} into ${output_dir}/${repo_name}"
    git clone "${ssh_url}" "${output_dir}/${repo_name}"
  done
}

main() {
  check_dependencies
  debug_mode="false"
  parse_arguments "$@"
  initialize
  fetch_and_clone_repos
  echo "Repositories cloned in ${output_dir}"
}

main "$@"
