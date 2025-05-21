# shellcheck shell=bash

# Generate a GitHub-style repository string and store it in GITHUB_REPOSLUG.
# If the Git repository is inside $HOME/github.com/davidsneighbour,
# use "davidsneighbour/REPO_NAME".
# Otherwise, extract it from the git remote.
# Exits with a warning if not in a git repo or no GitHub remote found.

__dnb_create_repopath() {
  local is_verbose="${DNB_VERBOSE:-false}"

  # Check if we're inside a git repository
  local repo_root
  if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    echo "Warning: Not inside a git repository." >&2
    return 1
  fi

  local repo_name
  repo_name="$(basename "${repo_root}")"

  # Check if inside $HOME/github.com/davidsneighbour
  if [[ "${repo_root}" == "${HOME}/github.com/davidsneighbour/"* ]]; then
    GITHUB_REPOSLUG="davidsneighbour/${repo_name}"
    [[ "${is_verbose}" == "true" ]] && echo "Repo identified by folder path: ${GITHUB_REPOSLUG}"
    return 0
  fi

  # Try to extract from git remote
  local remote_url
  remote_url="$(git remote get-url origin 2>/dev/null || true)"

  if [[ -z "${remote_url}" ]]; then
    echo "Warning: No git remote 'origin' found." >&2
    return 1
  fi

  if [[ "${remote_url}" =~ github\.com[:/](.+)/(.+?)(\.git)?$ ]]; then
    GITHUB_REPOSLUG="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    [[ "${is_verbose}" == "true" ]] && echo "Repo identified by remote: ${GITHUB_REPOSLUG}"
    return 0
  else
    echo "Warning: Git remote is not on GitHub." >&2
    return 1
  fi
}
