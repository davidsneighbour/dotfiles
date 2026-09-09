#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
  pwd
)"
readonly ROOTFS="${SCRIPT_DIR}/rootfs"

usage() {
  cat <<'EOF'
Restore the Argon ONE V2 configuration and software snapshot.

Usage:
  install.sh --install
  install.sh --help

Options:
  --install    Restore files and enable the Argon service.
  --help       Show this help.
EOF
}

check_dependencies() {
  local missing=0

  if ! /usr/bin/python3 -c 'import smbus' >/dev/null 2>&1; then
    printf 'Error: Python module "smbus" is missing.\n' >&2
    printf 'Install package: python3-smbus\n' >&2
    missing=1
  fi

  if ! /usr/bin/python3 -c 'import gpiod' >/dev/null 2>&1; then
    printf 'Error: Python module "gpiod" is missing.\n' >&2
    printf 'Install package: python3-libgpiod\n' >&2
    missing=1
  fi

  if ((missing != 0)); then
    return 1
  fi
}

install_argon() {

  check_dependencies

  if [[ ! -d "${ROOTFS}/etc/argon" ]]; then
    printf 'Error: snapshot not found: %s\n' "${ROOTFS}" >&2
    return 1
  fi

  printf 'Restoring Argon ONE V2 files...\n'

  sudo cp -a "${ROOTFS}/etc/argon" /etc/

  if [[ -f "${ROOTFS}/etc/argononed.conf" ]]; then
    sudo cp -a "${ROOTFS}/etc/argononed.conf" /etc/
  fi

  if [[ -f "${ROOTFS}/etc/argonunits.conf" ]]; then
    sudo cp -a "${ROOTFS}/etc/argonunits.conf" /etc/
  fi

  if [[ -f "${ROOTFS}/lib/systemd/system/argononed.service" ]]; then
    sudo cp -a \
      "${ROOTFS}/lib/systemd/system/argononed.service" \
      /lib/systemd/system/
  fi

  if [[ -f "${ROOTFS}/lib/systemd/system-shutdown/argon-shutdown.sh" ]]; then
    sudo mkdir -p /lib/systemd/system-shutdown
    sudo cp -a \
      "${ROOTFS}/lib/systemd/system-shutdown/argon-shutdown.sh" \
      /lib/systemd/system-shutdown/
  fi

  if [[ -d "${ROOTFS}/usr/bin" ]]; then
    sudo cp -a "${ROOTFS}/usr/bin/." /usr/bin/
  fi

  sudo systemctl daemon-reload
  sudo systemctl enable --now argononed.service

  printf '\nArgon ONE V2 restored.\n'
  sudo systemctl --no-pager --full status argononed.service
}

main() {
  case "${1:-}" in
  --install)
    install_argon
    ;;
  --help | -h)
    usage
    ;;
  *)
    usage >&2
    return 2
    ;;
  esac
}

main "$@"
