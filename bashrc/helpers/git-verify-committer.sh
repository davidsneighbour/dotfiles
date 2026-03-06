#!/bin/bash
set -euo pipefail

git_verify_debug() {
  local help="Usage: $(basename "$0") git_verify_debug --commit <sha>

Shows author/committer/signature details for a commit and validates the signature locally.

Options:
  --commit <sha>   Commit SHA (or ref) to inspect
  --help           Show this help
"
  local commit=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --commit)
      commit="${2:-}"
      shift 2
      ;;
    --help)
      echo "${help}"
      return 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "${help}" >&2
      return 2
      ;;
    esac
  done

  if [[ -z "${commit}" ]]; then
    echo "Error: --commit is required" >&2
    echo "${help}" >&2
    return 2
  fi

  echo "== git show (signature block) =="
  git show --show-signature --no-patch "${commit}" || true
  echo

  echo "== author/committer lines =="
  git log -1 --format=$'commit %H%nAuthor: %an <%ae>%nCommitter: %cn <%ce>%n' "${commit}"
  echo

  echo "== signature verification (raw) =="
  git verify-commit -v "${commit}" || true
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  git_verify_debug "$@"
fi
