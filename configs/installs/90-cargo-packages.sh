#!/bin/bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERBOSE=false
DRY_RUN=false

APT_BUILD_DEPS=(
  build-essential
  git
  pkg-config
  libgtk-3-dev
  libglib2.0-dev
  libpango1.0-dev
  libgdk-pixbuf-2.0-dev
  libcairo2-dev
  libdbusmenu-gtk3-dev
  libx11-dev
  libxrandr-dev
  libxi-dev
  libxext-dev
  libxcb1-dev
  libdbus-1-dev
  libgtk-layer-shell-dev
)

EWW_REPO_DIR="${HOME}/github.com/elkowar/eww"

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--verbose] [--dry-run] [--help]

Install eww's apt build dependencies, clone (if missing) and build eww from
source with cargo, and install the release binary to ~/.local/bin.

Options:
  --verbose   Trace each command as it runs.
  --dry-run   Print what would run without changing anything.
  --help      Show this help.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
  --verbose)
    VERBOSE=true
    shift
    ;;
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  --help)
    print_help
    exit 0
    ;;
  *)
    echo "Unknown argument: ${1}" >&2
    print_help >&2
    exit 1
    ;;
  esac
done

if [[ "${DRY_RUN}" == true ]]; then
  cat <<EOF
Would run:
  1. sudo apt install --yes ${APT_BUILD_DEPS[*]}
  2. Clone https://github.com/elkowar/eww to ${EWW_REPO_DIR} if missing
  3. cargo clean && cargo build --release --no-default-features --features x11
  4. Install target/release/eww to ~/.local/bin/
EOF
  exit 0
fi

if [[ "${VERBOSE}" == true ]]; then
  set -x
fi

sudo apt install --yes "${APT_BUILD_DEPS[@]}"

mkdir -p "$(dirname "${EWW_REPO_DIR}")"
if [[ ! -d "${EWW_REPO_DIR}/.git" ]]; then
  git clone https://github.com/elkowar/eww "${EWW_REPO_DIR}"
fi

cd "${EWW_REPO_DIR}" || exit 1
cargo clean
cargo build --release --no-default-features --features x11

mkdir -p "${HOME}/.local/bin"
mv target/release/eww "${HOME}/.local/bin/"

eww --help
