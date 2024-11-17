#!/bin/bash

# Default configuration
MIN_PREFIX=001
MAX_PREFIX=999
INSTALL_DIR="./setup/install"

# Function to show help
show_help() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  --min-prefix <number>    Set the minimum prefix number (default: 001)"
  echo "  --max-prefix <number>    Set the maximum prefix number (default: 999)"
  echo "  --install-dir <path>     Set the directory containing scripts (default: ./setup/install)"
  echo "  --help                   Show this help message"
  echo
  exit 0
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --min-prefix)
    MIN_PREFIX="$2"
    shift 2
    ;;
  --max-prefix)
    MAX_PREFIX="$2"
    shift 2
    ;;
  --install-dir)
    INSTALL_DIR="$2"
    shift 2
    ;;
  --help)
    show_help
    ;;
  *)
    echo "Unknown option: $1"
    show_help
    ;;
  esac
done

# Validate the configuration
if [[ ! "${MIN_PREFIX}" =~ ^[0-9]+$ ]] || [[ ! "${MAX_PREFIX}" =~ ^[0-9]+$ ]]; then
  echo "Error: Prefix values must be numeric."
  exit 1
fi

# Ensure the install directory exists
if [[ ! -d "${INSTALL_DIR}" ]]; then
  echo "Error: Install directory '${INSTALL_DIR}' does not exist."
  exit 1
fi

# Find and execute scripts within the prefix range
for script in "${INSTALL_DIR}"/*.sh; do
  script_name=$(basename "${script}")
  script_prefix=${script_name%%-*}

  # Check if prefix is within range
  if [[ "${script_prefix}" =~ ^[0-9]+$ ]] && ((script_prefix >= MIN_PREFIX)) && ((script_prefix <= MAX_PREFIX)); then
    echo "Executing: ${script_name}"
    bash "${script}"
    # shellcheck disable=SC2181
    if [[ $? -ne 0 ]]; then
      echo "Error: Script '${script_name}' failed."
      exit 1
    fi
  fi
done

echo "All scripts executed successfully."
