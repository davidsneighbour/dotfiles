#!/bin/bash
# dotbot.sh - Run Dotbot with a chosen config file.
# Usage:
#   ./dotbot.sh                      # uses etc/config.yaml
#   ./dotbot.sh --config setup       # uses etc/config.setup.yaml
#   ./dotbot.sh --config=protected   # uses etc/config.protected.yaml
#   ./dotbot.sh setup                # same as --config setup
#   ./dotbot.sh --list               # list available configs
#   ./dotbot.sh --help               # show help
#
# Notes:
# - If the value contains a slash or ends with .yaml, it is used as-is.
# - Otherwise it is mapped to etc/config.<value>.yaml
# - Fails nicely if the resolved file does not exist.

set -euo pipefail

print_help() {
  cat <<'EOF'
Usage:
  dotbot.sh [--config <name|path>] [--list] [--help]

Options:
  --config <name|path>  Name or path to config:
                        - "setup" -> etc/config.setup.yaml
                        - "./etc/custom.yaml" -> used as-is
  --list                List available etc/config.*.yaml files
  --help                Show this help

No option defaults to etc/config.yaml.
EOF
}

list_configs() {
  # List etc/config.*.yaml, if any
  if compgen -G "etc/config.*.yaml" >/dev/null; then
    printf 'Available configs:\n'
    # shellcheck disable=SC2012
    ls -1 etc/config.*.yaml | sed 's/^/  - /'
  else
    printf 'No etc/config.*.yaml files found.\n'
  fi
}

die() {
  printf 'Error: %s\n' "$1" >&2
  printf '\n' >&2
  list_configs >&2
  printf '\nUse --help for usage.\n' >&2
  exit 2
}

resolve_config_path() {
  # Arg: user-supplied name or path
  local input="${1}"
  # Use as-is if looks like a path or already a yaml file
  if [[ "${input}" == */* || "${input}" == *.yaml ]]; then
    printf '%s\n' "${input}"
  else
    printf 'etc/config.%s.yaml\n' "${input}"
  fi
}

main() {
  local config="etc/config.yaml"
  local pos_arg=""
  local arg

  # Parse args (simple, shellcheck-friendly)
  for arg in "${@:-}"; do
    case "${arg}" in
      --help|-h)
        print_help
        exit 0
        ;;
      --list)
        list_configs
        exit 0
        ;;
      --config=*)
        config="$(resolve_config_path "${arg#*=}")"
        ;;
      --config)
        # Next token must exist
        shift || die "--config requires a value"
        config="$(resolve_config_path "${1}")"
        ;;
      --*) # unknown long option
        die "Unknown option: ${arg}"
        ;;
      *) # first positional taken as config name
        if [[ -z "${pos_arg}" ]]; then
          pos_arg="${arg}"
          config="$(resolve_config_path "${pos_arg}")"
        else
          die "Unexpected extra argument: ${arg}"
        fi
        ;;
    esac
    # Shift handled for --config above only
  done

  # Validate file
  if [[ ! -f "${config}" ]]; then
    die "Config not found: ${config}"
  fi

  # Constants
  local DOTBOT_DIR="dotbot"
  local DOTBOT_BIN="bin/dotbot"
  # shellcheck disable=SC2155
  local BASEDIR
  BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  cd "${BASEDIR}"

  # Ensure submodule
  git -C "${DOTBOT_DIR}" submodule sync --quiet --recursive
  git submodule update --init --recursive "${DOTBOT_DIR}"

  HOSTNAME="$(hostname)"
  export HOSTNAME

  "${BASEDIR}/${DOTBOT_DIR}/${DOTBOT_BIN}" \
    --base-directory "${BASEDIR}" \
    --config-file "${config}" \
    --force-color \
    --exit-on-failure \
    -vv
}

main "$@"
