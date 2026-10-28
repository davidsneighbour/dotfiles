#!/bin/bash

# Contract tests for the terminal UI facade (bashrc/lib/00-core/dnb-core-ui.bash).
# Non-TTY paths run directly; terminal paths run inside `script` (util-linux).

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../../.." && pwd)"
CORE_DIR="${REPO_ROOT}/bashrc/lib/00-core"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

# Keep test logs away from personal logs.
export __LOGFILE="${WORK_DIR}/test.log"
export TERM=xterm-256color
unset NO_COLOR DNB_UI_FORMAT DNB_UI_QUIET DNB_UI_THEME DNB_UI_SYMBOLS DNB_COLOR_MODE DNB_UI_DISABLE

load_libs() {
  local file=''
  for file in dnb-core-colors dnb-core-log dnb-core-ui-theme dnb-core-ui; do
    # shellcheck disable=SC1090
    source "${CORE_DIR}/${file}.bash"
  done
}

fail() {
  printf 'FAIL: %s\n' "${1}" >&2
  exit 1
}

assert_equal() {
  if [[ "${1}" != "${2}" ]]; then
    printf 'FAIL: %s\nExpected: %q\nActual:   %q\n' "${3}" "${1}" "${2}" >&2
    exit 1
  fi
}

assert_no_escape() {
  [[ "${1}" != *$'\033'* ]] || fail "${2}: output contains escape sequences"
}

# Sourcing defines functions only: no output and unchanged shell flags.
test_source_is_side_effect_free() {
  local before='' after='' output=''
  before="$(set +o)"
  output="$(load_libs 2>&1)"
  load_libs
  load_libs
  after="$(set +o)"
  assert_equal '' "${output}" 'sourcing prints nothing'
  assert_equal "${before}" "${after}" 'sourcing keeps shell options'
}

test_palette() {
  assert_equal '30' "${#__DNB_UI_PALETTE_MAIN[@]}" 'main palette rows'
  assert_equal '6' "${#__DNB_UI_PALETTE_DARK[@]}" 'dark palette rows'
  assert_equal '#22212C|34,33,44|250° 15% 15%|59' "${__DNB_UI_PALETTE_MAIN[Black]}" 'Black row verbatim'
  assert_equal '#FFCA80|255,202,128|35° 100% 75%|222' "${__DNB_UI_PALETTE_MAIN[Orange]}" 'Orange row verbatim'
  assert_equal '#22212C' "$(__dnb_ui_palette_field Background hex)" 'main background'
  assert_equal '#0B0D0F' "$(DNB_UI_THEME=dracula-pro-dark __dnb_ui_palette_field Background hex)" 'dark background'
  assert_equal '#22212C' "$(DNB_UI_THEME=dracula-pro-dark __dnb_ui_palette_field Black hex)" 'dark keeps Black'
  assert_equal '255;202;128' "$(__dnb_ui_role_field warning rgb)" 'warning role rgb'
  assert_equal '109' "$(DNB_UI_THEME=dracula-pro-dark __dnb_ui_role_field muted 256)" 'dark muted 256'
  assert_equal '#FF80BF' "$(DNB_COLOR_MODE=truecolor __dnb_ui_backend_color skip)" 'backend hex'
  assert_equal '1' "$(DNB_COLOR_MODE=basic __dnb_ui_backend_color error)" 'backend basic slot'
}

test_exported_tokens() {
  local output=''
  output="$(dnb_ui_export_tokens && printf '%s %s' "${DNB_UI_ACCENT}" "${DNB_UI_WARNING}")"
  assert_equal '#80FFEA #FFCA80' "${output}" 'exported tokens'
  output="$(DNB_UI_THEME=dracula-pro-dark && dnb_ui_export_tokens && printf '%s' "${DNB_UI_BG}")"
  assert_equal '#0B0D0F' "${output}" 'exported dark tokens'
}

test_modes_and_symbols() {
  assert_equal 'json' "$(DNB_UI_FORMAT=json dnb_ui_mode)" 'json mode'
  assert_equal 'plain' "$(DNB_UI_FORMAT=plain dnb_ui_mode)" 'plain mode'
  assert_equal 'plain' "$(TERM=dumb dnb_ui_mode)" 'dumb terminal is plain'
  assert_equal 'OK' "$(DNB_UI_SYMBOLS=ascii dnb_ui_symbol success)" 'ascii symbol'
  assert_equal '✓' "$(DNB_UI_SYMBOLS=unicode dnb_ui_symbol success)" 'unicode symbol'
  assert_equal 'ERROR' "$(LANG=C LC_ALL='' LC_CTYPE='' dnb_ui_symbol error)" 'auto ascii without UTF-8'
  assert_equal '->' "$(DNB_UI_FORMAT=plain LANG=C.UTF-8 dnb_ui_symbol action)" 'plain forces ascii'
  dnb_ui_symbol nonsense 2>/dev/null && fail 'unknown symbol accepted'
  return 0
}

test_colour_capability() {
  # stdout of command substitution is not a terminal.
  if DNB_COLOR_MODE=truecolor dnb_ui_supports_color --fd 1; then
    fail 'forced colour mode must not colour redirected output'
  fi
  dnb_ui_supports_color --fd x 2>/dev/null && fail 'invalid fd accepted'
  return 0
}

test_style_code() {
  local code='x' status=0
  dnb_ui_style_code code error
  assert_equal '' "${code}" 'style code empty for a non-terminal stdout'
  dnb_ui_style_code code nonsense 2>/dev/null || status=$?
  assert_equal '2' "${status}" 'style code rejects unknown role'
  status=0
  dnb_ui_style_code 'bad name' error 2>/dev/null || status=$?
  assert_equal '2' "${status}" 'style code rejects invalid variable'
}

test_messages_use_stderr() {
  local out='' err=''
  out="$(dnb_ui_info 'hello' 2>"${WORK_DIR}/err")"
  err="$(cat "${WORK_DIR}/err")"
  assert_equal '' "${out}" 'info writes nothing to stdout'
  [[ "${err}" == *'info'*'hello'* ]] || fail 'info message missing on stderr'
  assert_no_escape "${err}" 'redirected stderr'
  out="$(DNB_UI_QUIET=1 dnb_ui_success 'x' 2>&1)"
  assert_equal '' "${out}" 'quiet suppresses success'
  out="$(DNB_UI_QUIET=1 dnb_ui_error 'boom' 2>&1)"
  [[ "${out}" == *'boom'* ]] || fail 'quiet keeps errors'
  out="$(dnb_ui_heading 'Title' 2>&1)"
  assert_equal '== Title ==' "${out}" 'plain heading'
  out="$(dnb_ui_heading $'bad\033[31m' 2>/dev/null)" && fail 'control characters accepted in heading'
  return 0
}

test_logger() {
  local out=''
  out="$(dnb_log info 'piped' 2>/dev/null)"
  assert_equal '' "${out}" 'dnb_log keeps stdout free'
  out="$(dnb_log info 'piped' 2>&1)"
  [[ "${out}" == *'piped'* ]] || fail 'dnb_log writes to stderr'
  assert_no_escape "${out}" 'dnb_log to a pipe'
  out="$(DNB_COLOR_MODE=none dnb_log info 'none' 2>&1)"
  assert_no_escape "${out}" 'dnb_log in none mode'
  out="$(dnb_log --json warn $'quote " back \\ tab \t nl \n ctl \001 ü')"
  printf '%s' "${out}" | python3 -c 'import json, sys; d = json.load(sys.stdin); assert d["message"] == "quote \" back \\ tab \t nl \n ctl \x01 ü", d' ||
    fail 'dnb_log --json output is not valid, exact JSON'
}

test_non_interactive_questions() {
  local out='' status=0
  out="$(dnb_ui_confirm --prompt 'Delete?' </dev/null 2>/dev/null)" || status=$?
  assert_equal '3' "${status}" 'confirm without terminal'
  assert_equal '' "${out}" 'confirm prints nothing'
  status=0
  out="$(dnb_ui_select --prompt 'Pick' --option a --option b </dev/null 2>/dev/null)" || status=$?
  assert_equal '3' "${status}" 'select without terminal'
  assert_equal '' "${out}" 'select invents no result'
  status=0
  dnb_ui_input --prompt 'Name' --default x </dev/null >/dev/null 2>&1 || status=$?
  assert_equal '3' "${status}" 'input without terminal ignores default'
  status=0
  dnb_ui_confirm --prompt 'x' --default yes >/dev/null 2>&1 || status=$?
  assert_equal '2' "${status}" 'confirm rejects default yes'
  status=0
  dnb_ui_select --prompt 'x' >/dev/null 2>&1 || status=$?
  assert_equal '2' "${status}" 'select needs options'
  status=0
  dnb_ui_select --prompt 'x' --option $'a\nb' >/dev/null 2>&1 || status=$?
  assert_equal '2' "${status}" 'select rejects control characters'
  status=0
  dnb_ui_search --prompt 'x' --items-file "${WORK_DIR}/missing" >/dev/null 2>&1 || status=$?
  assert_equal '2' "${status}" 'search needs a readable file'
}

test_spin_preserves_streams() {
  local out='' err='' status=0
  out="$(dnb_ui_spin --title 'Working' -- bash -c 'echo OUT; echo ERR >&2; exit 7' 2>"${WORK_DIR}/spin-err")" || status=$?
  err="$(cat "${WORK_DIR}/spin-err")"
  assert_equal '7' "${status}" 'spin returns child status'
  assert_equal 'OUT' "${out}" 'spin keeps child stdout'
  [[ "${err}" == *'Working'* && "${err}" == *'ERR'* ]] || fail 'spin progress and child stderr on stderr'
  out="$(dnb_ui_spin --title 'Count' -- bash -c 'echo run >>"$1"' _ "${WORK_DIR}/runs" 2>/dev/null)"
  assert_equal '1' "$(wc -l <"${WORK_DIR}/runs" | tr -d ' ')" 'spin runs the command once'
}

test_table_plain() {
  local out=''
  printf 'Name\tState\nalpha\tok\nb\tchanged\n' >"${WORK_DIR}/table.tsv"
  out="$(dnb_ui_table --input "${WORK_DIR}/table.tsv")"
  assert_equal $'Name   State\n-----  -------\nalpha  ok\nb      changed' "${out}" 'plain table'
  out="$(dnb_ui_table --input "${WORK_DIR}/table.tsv" --stream stderr 2>/dev/null)"
  assert_equal '' "${out}" 'stderr table keeps stdout empty'
}

test_renderers_plain_when_redirected() {
  local out=''
  printf '# Title\n\nText *with* emphasis.\n' >"${WORK_DIR}/doc.md"
  printf -- '--- a\n+++ b\n@@ -1 +1 @@\n-old\n+new\n' >"${WORK_DIR}/change.diff"
  out="$(dnb_ui_markdown --file "${WORK_DIR}/doc.md")"
  assert_equal "$(cat "${WORK_DIR}/doc.md")" "${out}" 'markdown unchanged when piped'
  out="$(dnb_ui_code --file "${WORK_DIR}/doc.md")"
  assert_equal "$(cat "${WORK_DIR}/doc.md")" "${out}" 'code unchanged when piped'
  out="$(dnb_ui_diff --file "${WORK_DIR}/change.diff")"
  assert_equal "$(cat "${WORK_DIR}/change.diff")" "${out}" 'diff unchanged when piped'
  dnb_ui_markdown --file "${WORK_DIR}/missing" >/dev/null 2>&1 && fail 'missing document accepted'
  return 0
}

# Terminal paths run in a pseudo-terminal. Gum is disabled so the plain
# fallbacks are exercised deterministically with typed answers.
run_in_pty() {
  local input="${1}"
  local snippet="${2}"
  local script_file="${WORK_DIR}/pty.sh"

  {
    printf 'export TERM=xterm-256color __LOGFILE=%q DNB_UI_DISABLE=%q LANG=C.UTF-8\n' "${__LOGFILE}" 'gum fzf glow bat delta'
    printf 'for f in dnb-core-colors dnb-core-log dnb-core-ui-theme dnb-core-ui; do source %q/$f.bash; done\n' "${CORE_DIR}"
    printf '%s\n' "${snippet}"
  } >"${script_file}"
  printf '%b' "${input}" | script -qec "bash ${script_file}" /dev/null 2>/dev/null | tr -d '\r'
}

test_pty_interaction() {
  if ! command -v script >/dev/null 2>&1; then
    printf 'SKIP: script (util-linux) not available; terminal tests skipped\n' >&2
    return 0
  fi
  local out=''
  out="$(run_in_pty '2\n' 'v="$(dnb_ui_select --prompt Pick --option "a b" --option "c d")"; echo "RESULT=[$v] rc=$?"')"
  [[ "${out}" == *'RESULT=[c d] rc=0'* ]] || fail "pty select: ${out}"
  out="$(run_in_pty '\n' 'dnb_ui_confirm --prompt Go; echo "rc=$?"')"
  [[ "${out}" == *'rc=1'* ]] || fail "pty confirm empty answer must decline: ${out}"
  out="$(run_in_pty 'yes\n' 'dnb_ui_confirm --prompt Go; echo "rc=$?"')"
  [[ "${out}" == *'rc=0'* ]] || fail "pty confirm yes: ${out}"
  out="$(run_in_pty '\n' 'v="$(dnb_ui_input --prompt Name --default dflt)"; echo "RESULT=[$v]"')"
  [[ "${out}" == *'RESULT=[dflt]'* ]] || fail "pty input default: ${out}"
  out="$(run_in_pty '\n' 'dnb_ui_select --prompt Pick --option a; echo "rc=$?"')"
  [[ "${out}" == *'rc=130'* ]] || fail "pty select cancel: ${out}"
  out="$(run_in_pty '' 'dnb_ui_style_code c error; dnb_ui_style_code r reset; printf "S=[%q%q]\n" "$c" "$r"')"
  [[ "${out}" == *"S=[\$'\\E[38;"* ]] || fail "pty style code: ${out}"
  out="$(run_in_pty '' 'dnb_ui_search --prompt Find --items-file /dev/null; echo "rc=$?"')"
  [[ "${out}" == *'rc=3'* ]] || fail "pty search without fzf: ${out}"
}

load_libs
test_source_is_side_effect_free
test_palette
test_exported_tokens
test_modes_and_symbols
test_colour_capability
test_style_code
test_messages_use_stderr
test_logger
test_non_interactive_questions
test_spin_preserves_streams
test_table_plain
test_renderers_plain_when_redirected
test_pty_interaction

printf 'PASS: dnb UI contracts\n'
