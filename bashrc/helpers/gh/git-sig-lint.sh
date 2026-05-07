#!/bin/bash
set -euo pipefail

git_sig_lint() {
  local help="Usage: $(basename "$0") git_sig_lint [--repo <path>] [--check-commits <n>] [--help]

A quick lint-style audit for Git commit signing + identity consistency.

Options:
  --repo <path>        Repository path (default: current directory)
  --check-commits <n>  Verify last n commits (default: 5)
  --help               Show this help
"
  local repo="."
  local n="5"

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --check-commits)
      n="${2:-}"
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

    local git_email
    git_email="$(git config --get user.email || true)"
    if [[ -z "${git_email}" ]]; then
      echo "FAIL: git user.email is not set"
      return 1
    fi

    local gpgsign
    gpgsign="$(git config --get commit.gpgsign || true)"
    if [[ "${gpgsign}" != "true" ]]; then
      echo "WARN: commit.gpgsign is not true (current: ${gpgsign:-<unset>})"
    fi

    local signingkey
    signingkey="$(git config --get user.signingkey || true)"
    if [[ -z "${signingkey}" ]]; then
      echo "WARN: user.signingkey is not set (Git may be picking a default key)"
    fi

    echo "OK: git user.email = ${git_email}"
    echo "OK: commit.gpgsign = ${gpgsign:-<unset>}"
    echo "OK: user.signingkey = ${signingkey:-<unset>}"
    echo

    echo "== GPG key UIDs (emails) =="
    if [[ -n "${signingkey}" ]]; then
      gpg --list-keys --keyid-format long "${signingkey}" 2>/dev/null | sed -n 's/.*<\(.*\)>.*/\1/p' || true
      echo
      if gpg --list-keys --keyid-format long "${signingkey}" 2>/dev/null | grep -q "<${git_email}>"; then
        echo "OK: git email exists on the signing key UID list"
      else
        echo "WARN: git email is NOT present on the signing key UID list"
      fi
    else
      echo "SKIP: no user.signingkey set"
    fi
    echo

    echo "== GPG signing sanity test =="
    if printf "sign-test" | gpg --clearsign >/dev/null 2>&1; then
      echo "OK: gpg can sign (agent/pinentry working)"
    else
      echo "FAIL: gpg signing failed (agent/pinentry issue)"
      return 1
    fi
    echo

    echo "== verify last ${n} commits locally =="
    local i=0
    while read -r sha; do
      i=$((i + 1))
      echo "Commit ${i}/${n}: ${sha}"
      git verify-commit -v "${sha}" >/dev/null 2>&1 && echo "  OK" || echo "  FAIL"
    done < <(git rev-list --max-count "${n}" HEAD)
    echo

    echo "== author/committer emails for last ${n} commits =="
    git log -n "${n}" --format=$'%h | A:%ae | C:%ce'
  )
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  git_sig_lint "$@"
fi
