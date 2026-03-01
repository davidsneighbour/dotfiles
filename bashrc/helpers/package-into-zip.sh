#!/bin/bash
# package: build a zip from a "packages.*" section in ~/.dotfiles/configs/hosts/<hostname>.toml

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<'EOF'
Usage:
  package --package <name> [--verbose]
  package <name> [--verbose]
  package --help

Description:
  Reads package file lists from:
    ~/.dotfiles/configs/hosts/<hostname-lowercase>.toml

  Expected config format:
    [packages.type-a]
    file-1
    path/to/file2
    path/to/folder1
    $HOME/path/to/folder/in/homedirectory

    [packages.type-b]
    file-2

Output:
  Creates a zip in the current directory named:
    <packagename>-YYYYMMDDHHMM.zip

Notes:
  * Lines under a [packages.<name>] header are treated as paths (one per line).
  * Empty lines and lines starting with '#' or ';' are ignored.
  * $HOME and '~' are expanded. Other $VARS are expanded only if `envsubst` is available.
EOF
}

err() {
  printf "Error: %s\n" "$*" >&2
}

info() {
  printf "%s\n" "$*"
}

log_setup() {
  local logs_dir="${HOME}/.logs/packages"
  mkdir -p "${logs_dir}"
  local ts
  ts="$(date +'%Y%m%d-%H%M%S')"
  LOG_FILE="${logs_dir}/setup-log-${ts}.log"
  printf "[%s] %s\n" "$(date -Is)" "start ${SCRIPT_NAME} ${*}" >>"${LOG_FILE}"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

hostname_lc() {
  local h
  h="$(hostname 2>/dev/null || true)"
  if [[ -z "${h}" ]]; then
    err "Unable to determine hostname."
    exit 1
  fi
  printf "%s" "${h}" | tr '[:upper:]' '[:lower:]'
}

config_path() {
  local h
  h="$(hostname_lc)"
  printf "%s/.dotfiles/configs/hosts/%s.toml" "${HOME}" "${h}"
}

list_packages() {
  local cfg="$1"
  if [[ ! -f "${cfg}" ]]; then
    err "Config file not found: ${cfg}"
    exit 1
  fi

  # Extract headers like: [packages.type-a]
  # Output: type-a
  awk '
    match($0, /^\[packages\.([A-Za-z0-9._-]+)\][[:space:]]*$/, m) { print m[1] }
  ' "${cfg}" | sort -u
}

expand_path_line() {
  local line="$1"

  # Trim leading/trailing whitespace
  line="$(printf "%s" "${line}" | sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//')"

  # Expand leading ~
  if [[ "${line}" == "~"* ]]; then
    line="${HOME}${line:1}"
  fi

  # Always expand $HOME occurrences (common in your examples)
  line="${line//\$HOME/${HOME}}"

  # Optionally expand other $VARS if envsubst exists (safer than eval)
  if have_cmd envsubst; then
    line="$(printf "%s" "${line}" | envsubst)"
  fi

  printf "%s" "${line}"
}

read_package_paths() {
  local cfg="$1"
  local pkg="$2"

  awk -v target="${pkg}" '
    BEGIN { in_section=0 }
    # Section header
    match($0, /^\[packages\.([A-Za-z0-9._-]+)\][[:space:]]*$/, m) {
      in_section = (m[1] == target) ? 1 : 0
      next
    }
    # Any other header ends the section
    /^\[/ { if (in_section == 1) exit 0; next }
    # Inside: ignore comments and empty lines
    in_section == 1 {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "" || line ~ /^[#;]/) next
      print line
    }
  ' "${cfg}"
}

make_zip_name() {
  local pkg="$1"
  local ts
  ts="$(date +'%Y%m%d%H%M')"
  printf "%s-%s.zip" "${pkg}" "${ts}"
}

main() {
  local pkg=""
  local verbose="0"

  if [[ "${#}" -eq 0 ]]; then
    usage
    info ""
    info "Available packages:"
    local cfg
    cfg="$(config_path)"
    if [[ -f "${cfg}" ]]; then
      list_packages "${cfg}" | sed 's/^/  - /'
    else
      info "  (config not found: ${cfg})"
    fi
    exit 0
  fi

  while [[ "${#}" -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --verbose)
        verbose="1"
        shift
        ;;
      --package)
        shift
        if [[ "${#}" -eq 0 ]]; then
          err "--package requires a value"
          usage
          exit 2
        fi
        pkg="$1"
        shift
        ;;
      --*)
        err "Unknown option: $1"
        usage
        exit 2
        ;;
      *)
        # Back-compat positional: package <name>
        if [[ -z "${pkg}" ]]; then
          pkg="$1"
          shift
        else
          err "Unexpected argument: $1"
          usage
          exit 2
        fi
        ;;
    esac
  done

  if [[ -z "${pkg}" ]]; then
    err "Missing package name."
    usage
    exit 2
  fi

  if ! have_cmd zip; then
    err "'zip' is required but not installed."
    err "Install it with: sudo apt install zip"
    exit 1
  fi

  log_setup "--package ${pkg} --verbose ${verbose}"

  local cfg
  cfg="$(config_path)"
  if [[ ! -f "${cfg}" ]]; then
    err "Config file not found: ${cfg}"
    exit 1
  fi

  # Validate package exists
  if ! list_packages "${cfg}" | grep -Fxq "${pkg}"; then
    err "Package '${pkg}' is not defined in ${cfg}"
    info ""
    info "Defined packages:"
    list_packages "${cfg}" | sed 's/^/  - /'
    exit 1
  fi

  # Read and expand paths
  local -a raw_lines=()
  local -a paths=()
  local line expanded

  while IFS= read -r line; do
    raw_lines+=("${line}")
  done < <(read_package_paths "${cfg}" "${pkg}")

  if [[ "${#raw_lines[@]}" -eq 0 ]]; then
    err "Package '${pkg}' exists but contains no paths."
    exit 1
  fi

  for line in "${raw_lines[@]}"; do
    expanded="$(expand_path_line "${line}")"
    paths+=("${expanded}")
  done

  # Check all paths exist
  local -a missing=()
  local p
  for p in "${paths[@]}"; do
    if [[ ! -e "${p}" ]]; then
      missing+=("${p}")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    err "Some paths do not exist. Aborting."
    printf "%s\n" "Missing paths:" >&2
    printf "  - %s\n" "${missing[@]}" >&2
    exit 1
  fi

  local out
  out="$(make_zip_name "${pkg}")"

  if [[ "${verbose}" == "1" ]]; then
    info "Config: ${cfg}"
    info "Package: ${pkg}"
    info "Output:  ${PWD}/${out}"
    info "Items:"
    printf "  - %s\n" "${paths[@]}"
  fi

  # Create zip (absolute and relative paths supported)
  # -r: include directories recursively
  zip -r "${out}" "${paths[@]}" >/dev/null

  info "${out}"
  printf "[%s] %s\n" "$(date -Is)" "created ${PWD}/${out}" >>"${LOG_FILE}"
}

main "$@"
