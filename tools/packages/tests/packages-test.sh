#!/bin/bash
#
# Tests for the packages tool. They run the real command against the fixture
# data in tests/fixtures/ (through PACKAGES_DATA_DIR), so they do not depend
# on the packages of this machine.
#
# Fixture graph (manual: appa, appb, curl, mail-app, tool-c):
#   appa -> libfoo -> libc6 (essential)    appb -> libbar -> libfoo
#   curl -> libcurl4 -> libnghttp2-14      curl -recommends-> bash-completion
#   libcurl4 -> "libnghttp2-14 | libnghttp3" (only the first is installed)
#   mail-app -> mail-transport-agent (virtual, provided by postfix)
#   tool-c -> cyca -> cycb -> cyca (cycle)
#   leftover, oldkernel: nobody needs them; only leftover is in orphans.txt
#   removed-pkg: status "rc" (config files only), so not installed

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES="${SCRIPT_DIR}/../packages"

export PACKAGES_DATA_DIR="${SCRIPT_DIR}/fixtures"
unset DNB_VERBOSE NO_COLOR

failures=0

fail() {
  printf 'FAIL: %s\n' "${1}" >&2
  failures=$((failures + 1))
}

# Run the command and compare stdout and the exit status.
assert_output() {
  local message="${1}"
  local expected_status="${2}"
  local expected="${3}"
  shift 3
  local actual
  local status=0

  actual="$("${PACKAGES}" "${@}" 2>/dev/null)" || status="${?}"
  if [[ "${status}" -ne "${expected_status}" ]]; then
    fail "${message}: exit status ${status}, expected ${expected_status}"
    return
  fi
  if [[ "${actual}" != "${expected}" ]]; then
    fail "${message}"
    diff <(printf '%s\n' "${expected}") <(printf '%s\n' "${actual}") >&2 || true
  fi
}

assert_status() {
  local message="${1}"
  local expected_status="${2}"
  shift 2
  local status=0

  "${PACKAGES}" "${@}" >/dev/null 2>&1 || status="${?}"
  if [[ "${status}" -ne "${expected_status}" ]]; then
    fail "${message}: exit status ${status}, expected ${expected_status}"
  fi
}

assert_output "why: several manual roots, shared dependency" 0 "$(
  cat <<'EOF'
libfoo [automatic]

Required through:

appa [manual]
└── libfoo [automatic]

appb [manual]
└── libbar [automatic]
    └── libfoo [automatic]
EOF
)" why libfoo

assert_output "why: alternative and virtual package" 0 "$(
  cat <<'EOF'
libnghttp2-14 [automatic]

Required through:

curl [manual]
└── libcurl4 [automatic]
    └── libnghttp2-14 [automatic]


postfix [automatic]

Required through:

mail-app [manual]
└── postfix [automatic]
EOF
)" why libnghttp2-14 --package postfix

assert_output "why: cycle" 0 "$(
  cat <<'EOF'
cyca [automatic]

Required through:

tool-c [manual]
└── cyca [automatic]
EOF
)" why cyca

assert_output "why: soft dependencies" 0 "$(
  cat <<'EOF'
bash-completion [automatic]

Required through:

curl [manual]
└── bash-completion [automatic] (recommends)

mail-app [manual]
└── postfix [automatic]
    └── bash-completion [automatic] (suggests)
EOF
)" why bash-completion

assert_output "why: no root, orphaned or kept by APT" 0 "$(
  cat <<'EOF'
leftover [automatic]

No manual or essential package needs it.
APT would remove it with autoremove (see `packages orphaned`).


oldkernel [automatic]

No manual or essential package needs it.
APT does not offer it for autoremove (for example, APT protects recent kernels).
EOF
)" why leftover oldkernel

assert_output "why: manual package that nothing needs" 0 "$(
  cat <<'EOF'
curl [manual]

Marked manual. No other manual or essential package needs it.
EOF
)" why curl

if [[ "$("${PACKAGES}" why libc6 --all | grep -c '^[a-z].*\[manual\]$')" -ne 5 ]]; then
  fail "why --all: expected 5 root paths for libc6"
fi

assert_output "tree: all manual packages" 0 "$(
  cat <<'EOF'
appa [manual]
└── libfoo [automatic]
    └── libc6 [automatic, essential]

appb [manual]
└── libbar [automatic]
    └── libfoo [automatic] (see above)

curl [manual]
├── libcurl4 [automatic]
│   ├── libnghttp2-14 [automatic]
│   │   └── libc6 [automatic, essential] (see above)
│   └── libc6 [automatic, essential] (see above)
├── libc6 [automatic, essential] (see above)
└── bash-completion [automatic] (recommends)

mail-app [manual]
└── postfix [automatic]
    ├── libc6 [automatic, essential] (see above)
    └── bash-completion [automatic] (suggests) (see above)

tool-c [manual]
└── cyca [automatic]
    └── cycb [automatic]
        ├── cyca [automatic] (see above)
        └── libc6 [automatic, essential] (see above)
EOF
)" tree

assert_output "tree: one package with --depth" 0 "$(
  cat <<'EOF'
curl [manual]
├── libcurl4 [automatic] ...
├── libc6 [automatic, essential]
└── bash-completion [automatic] (recommends)
EOF
)" tree curl --depth 1

assert_output "manual" 0 "$(printf '%s\n' appa appb curl mail-app tool-c)" manual
assert_output "automatic: installed minus manual, removed-pkg not listed" 0 "$(
  printf '%s\n' bash-completion cyca cycb leftover libbar libc6 libcurl4 libfoo libnghttp2-14 oldkernel postfix
)" automatic
assert_output "orphaned" 0 "leftover" orphaned
list_output="$("${PACKAGES}" list)"
if [[ "$(grep -c . <<<"${list_output}")" -ne 16 ]]; then
  fail "list: expected 16 installed packages"
fi
if ! grep -qx "$(printf '%-48s %-9s %s' libc6 automatic 2.40)" <<<"${list_output}" ||
  ! grep -qx "$(printf '%-48s %-9s %s' mail-app manual 1.0)" <<<"${list_output}"; then
  fail "list: wrong mark or version"
fi

assert_output "find: substring" 0 "$(
  printf '%-48s %s\n' curl manual curlftpfs - libcurl4 automatic libcurl4-dev -
)" find curl
assert_output "find: glob matches the whole name" 0 "$(
  printf '%-48s %s\n' libcurl4 automatic libcurl4-dev -
)" find 'lib?url*'
assert_output "why: glob against installed packages" 0 "$(
  "${PACKAGES}" why libbar libfoo
)" why 'libba[r]' 'libf*'

assert_status "no arguments print help" 2
assert_status "--help" 0 --help
assert_status "unknown command" 2 bogus
assert_status "unknown option" 2 list --bogus
assert_status "why without a name" 2 why
assert_status "list does not take names" 2 list curl
assert_status "--depth needs a number" 2 tree --depth x
assert_status "why: no installed match" 1 why removed-pkg
assert_status "why: one of two patterns has no match" 1 why libfoo nosuch
assert_status "find: no match" 1 find zzz

if [[ "${failures}" -gt 0 ]]; then
  printf '%s test(s) failed.\n' "${failures}" >&2
  exit 1
fi
printf 'packages tests passed.\n'
