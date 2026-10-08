#!/bin/bash
#
# The i3 session configuration in this repository is complete and loads: i3
# validates its config, session scripts parse and are executable, Polybar
# include folders and Rofi @import targets exist, and every ~/.dotfiles path
# that the i3 and Polybar configs call exists.
#
# This check reads the repository that contains system-checkup, not the live
# ~/.dotfiles link, so `npm run test:shell` can run it against a working tree.
# It changes nothing and needs no running desktop.

# Checks run through system-checkup, which exports SYSTEM_CHECKUP_DIR.
: "${SYSTEM_CHECKUP_DIR:?run this check with: system-checkup --check <name>}"

REPO_ROOT="$(cd -- "${SYSTEM_CHECKUP_DIR}/../.." && pwd)"
SESSION_DIR="${REPO_ROOT}/configs/session"
I3_CONFIG="${SESSION_DIR}/i3/config"
POLYBAR_DIR="${SESSION_DIR}/polybar"
ROFI_DIR="${SESSION_DIR}/rofi"

PROBLEMS=()

problem() {
  PROBLEMS+=("${1}")
}

relative() {
  printf '%s' "${1#"${REPO_ROOT}"/}"
}

check_i3_config() {
  local output
  local detail
  local file

  if [[ ! -f "${I3_CONFIG}" ]]; then
    problem "i3 config is missing: $(relative "${I3_CONFIG}")"
    return
  fi
  if ! command -v i3 >/dev/null 2>&1; then
    printf 'i3 is not installed; i3 config validation skipped\n'
    return
  fi
  # i3 -C exits 0 on some errors, so its output counts as well. It does not
  # check the commands inside bindings (see
  # .agents/instructions/session/i3-keybindings.instructions.md).
  if ! output="$(i3 -C -c "${I3_CONFIG}" 2>&1)" || [[ -n "${output}" ]]; then
    # i3 prints the failing line just above the "^^^" marker.
    detail="$(grep -B1 -m1 '\^\^\^' <<<"${output}" | head -n1)"
    detail="${detail#*CONFIG: }"
    file="$(grep -o -m1 '(in file [^)]*)' <<<"${output}")"
    file="${file#(in file }"
    file="${file%)}"
    problem "i3 config does not validate: ${file:+$(relative "${file}") }${detail:-${output%%$'\n'*}} (run: i3 -C -c $(relative "${I3_CONFIG}"))"
  fi
}

# Bash scripts must parse and Python scripts must compile; both must be
# executable, because i3, Polybar, and Rofi start them directly.
check_session_scripts() {
  local file
  local first_line
  local count=0

  while IFS= read -r -d '' file; do
    IFS= read -r first_line <"${file}" || first_line=""
    case "${first_line}" in
      '#!'*bash*)
        if ! bash -n "${file}" 2>/dev/null; then
          problem "Bash syntax error: $(relative "${file}") (run: bash -n $(relative "${file}"))"
        fi
        ;;
      '#!'*python3*)
        if command -v python3 >/dev/null 2>&1 \
          && ! python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1])' "${file}" 2>/dev/null; then
          problem "Python syntax error: $(relative "${file}")"
        fi
        ;;
      '#!'*) ;;
      *)
        continue
        ;;
    esac
    count=$((count + 1))
    if [[ ! -x "${file}" ]]; then
      problem "Script is not executable: $(relative "${file}") (run: chmod +x $(relative "${file}"))"
    fi
  done < <(
    find "${SESSION_DIR}/i3" "${POLYBAR_DIR}" "${ROFI_DIR}" \
      \( -name scratch -o -name __pycache__ \) -prune -o \
      -type f -print0
  )
  printf '%s session scripts checked\n' "${count}"
}

check_polybar_includes() {
  local line
  local include_directory

  while IFS= read -r line; do
    include_directory="${line#*=}"
    include_directory="${include_directory#"${include_directory%%[![:space:]]*}"}"
    include_directory="${include_directory%"${include_directory##*[![:space:]]}"}"
    if [[ ! -d "${POLYBAR_DIR}/${include_directory}" ]]; then
      problem "Polybar include-directory is missing: $(relative "${POLYBAR_DIR}/${include_directory}")"
    fi
  done < <(grep -hE '^[[:space:]]*include-directory[[:space:]]*=' "${POLYBAR_DIR}"/*.ini)
}

check_rofi_imports() {
  local source_file
  local import_line
  local import_file
  local candidate

  while IFS=: read -r source_file import_line; do
    import_file="${import_line#*@import }"
    import_file="${import_file%\"}"
    import_file="${import_file#\"}"

    # Rofi resolves `@import "name"` against its own config folder as well
    # as the folder of the importing file (power/powermenu.rasi imports
    # "theme" from the Rofi root), with or without the .rasi extension.
    for candidate in \
      "$(dirname "${source_file}")/${import_file}" \
      "$(dirname "${source_file}")/${import_file}.rasi" \
      "${ROFI_DIR}/${import_file}" \
      "${ROFI_DIR}/${import_file}.rasi"; do
      if [[ -f "${candidate}" ]]; then
        continue 2
      fi
    done
    problem "Rofi @import target \"${import_file}\" is missing (imported from $(relative "${source_file}"))"
  done < <(grep -RE '^[[:space:]]*@import[[:space:]]+"[^"]+"' "${ROFI_DIR}")
}

# The i3 and Polybar configs call scripts and read files by their
# ~/.dotfiles path. Each path must exist in this repository, and a file with a
# shebang must be executable.
check_dotfiles_references() {
  local reference
  local path
  local first_line
  local count=0

  while IFS= read -r reference; do
    path="${REPO_ROOT}/${reference#*/.dotfiles/}"
    count=$((count + 1))
    if [[ ! -e "${path}" ]]; then
      problem "Referenced path is missing: ${reference}"
      continue
    fi
    if [[ -f "${path}" ]]; then
      IFS= read -r first_line <"${path}" || first_line=""
      if [[ "${first_line}" == '#!'* && ! -x "${path}" ]]; then
        problem "Referenced script is not executable: ${reference} (run: chmod +x $(relative "${path}"))"
      fi
    fi
  done < <(
    grep -rhoE '(\$\{?HOME\}?|~)/\.dotfiles/[[:alnum:]_./-]+' \
      "${I3_CONFIG}" "${SESSION_DIR}/i3/configs" \
      "${POLYBAR_DIR}/config.ini" "${POLYBAR_DIR}/configs" \
      | sort -u
  )
  printf '%s ~/.dotfiles references checked\n' "${count}"
}

check_i3_config
check_session_scripts
check_polybar_includes
check_rofi_imports
check_dotfiles_references

if [[ "${#PROBLEMS[@]}" -gt 0 ]]; then
  for entry in "${PROBLEMS[@]}"; do
    printf '%s\n' "${entry}"
  done
  printf 'Fix: correct the files above in %s, then run: system-checkup --check 31-session-config\n' "$(relative "${SESSION_DIR}")"
  exit 1
fi
printf 'i3, Polybar, and Rofi configuration is complete\n'
exit 0
