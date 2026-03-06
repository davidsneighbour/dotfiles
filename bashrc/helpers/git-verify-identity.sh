#!/bin/bash
set -euo pipefail

git_identity_audit() {
  local help="Usage: $(basename "$0") git_identity_audit [--repo <path>] [--help]

Prints effective Git identity and where config values come from.

Options:
  --repo <path>   Repository path (default: current directory)
  --help          Show this help
"
  local repo="."

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --repo)
      repo="${2:-}"
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

  (
    cd "${repo}" >/dev/null

    echo "== effective identity =="
    echo "user.name:  $(git config --get user.name || true)"
    echo "user.email: $(git config --get user.email || true)"
    echo

    echo "== signing config =="
    echo "commit.gpgsign: $(git config --get commit.gpgsign || true)"
    echo "gpg.format:     $(git config --get gpg.format || true)"
    echo "user.signingkey:$(git config --get user.signingkey || true)"
    echo "gpg.program:    $(git config --get gpg.program || true)"
    echo

    echo "== where do these come from? (origin) =="
    git config --show-origin --get-all user.name || true
    git config --show-origin --get-all user.email || true
    git config --show-origin --get-all user.signingkey || true
    git config --show-origin --get-all commit.gpgsign || true
    git config --show-origin --get-all gpg.format || true
    echo

    echo "== includes (can override unexpectedly) =="
    git config --show-origin --get-all include.path || true
    git config --show-origin --get-all includeIf.gitdir:/.path || true
    git config --show-origin --get-all includeIf.gitdir/i:.path || true
    echo
  )
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  git_identity_audit "$@"
fi
