#!/bin/bash

# shellcheck disable=SC2155

set -euo pipefail

###############################################################################
# nfs-storage-setup.sh
#
# Configure an NFS server or client for a shared storage path.
#
# Default setup:
# * Server export path: /mnt/storage
# * Client mount point: /mnt/storage
# * Server address: 192.168.1.201
# * Allowed client subnet: 192.168.1.0/24
#
# Features:
# * --server / --client
# * --setup          Install required packages
# * --setup-daemon   Write NFS or systemd configuration
# * --reload         Reload the related daemons / systemd units
# * --verbose        More output
# * --help           Show help
#
# Notes:
# * This script writes files under /etc and uses sudo for privileged steps.
# * The client setup uses systemd automount plus a retry timer.
###############################################################################

###############################################################################
# Configuration defaults
###############################################################################

readonly DEFAULT_SERVER_IP="192.168.1.201"
readonly DEFAULT_ALLOWED_NETWORK="192.168.1.0/24"
readonly DEFAULT_EXPORT_PATH="/mnt/storage"
readonly DEFAULT_MOUNT_POINT="/mnt/storage"
readonly DEFAULT_OWNER_UID="1000"
readonly DEFAULT_OWNER_GID="1000"

readonly SERVER_EXPORTS_FILE="/etc/exports.d/storage.exports"

readonly CLIENT_MOUNT_UNIT="/etc/systemd/system/mnt-storage.mount"
readonly CLIENT_AUTOMOUNT_UNIT="/etc/systemd/system/mnt-storage.automount"
readonly CLIENT_RETRY_SERVICE="/etc/systemd/system/mnt-storage-retry.service"
readonly CLIENT_RETRY_TIMER="/etc/systemd/system/mnt-storage-retry.timer"

###############################################################################
# Runtime variables
###############################################################################

ROLE=""
DO_SETUP="false"
DO_SETUP_DAEMON="false"
DO_RELOAD="false"
VERBOSE="false"

SERVER_IP="${DEFAULT_SERVER_IP}"
ALLOWED_NETWORK="${DEFAULT_ALLOWED_NETWORK}"
EXPORT_PATH="${DEFAULT_EXPORT_PATH}"
MOUNT_POINT="${DEFAULT_MOUNT_POINT}"
OWNER_UID="${DEFAULT_OWNER_UID}"
OWNER_GID="${DEFAULT_OWNER_GID}"

###############################################################################
# Logging helpers
###############################################################################

log_info() {
  printf '[info] %s\n' "$*"
}

log_warn() {
  printf '[warn] %s\n' "$*" >&2
}

log_error() {
  printf '[error] %s\n' "$*" >&2
}

log_verbose() {
  if [[ "${VERBOSE}" == "true" ]]; then
    printf '[verbose] %s\n' "$*"
  fi
}

die() {
  log_error "$*"
  exit 1
}

###############################################################################
# Help
###############################################################################

show_help() {
  local script_name
  script_name="$(basename "$0")"

  cat <<EOF
Usage: ${script_name} [--server | --client] [OPTIONS]

Roles:
  --server                 Run server-side tasks for the NFS host
  --client                 Run client-side tasks for the mounting host

Actions:
  --setup                  Install required packages for the selected role
  --setup-daemon           Write configuration files for the selected role
  --reload                 Reload the selected role after changes

Configuration:
  --server-ip <ip>         Server IP address for the NFS host
                           Default: ${DEFAULT_SERVER_IP}

  --allowed-network <cidr> Allowed client network for the NFS export
                           Default: ${DEFAULT_ALLOWED_NETWORK}

  --export-path <path>     Export path on the server
                           Default: ${DEFAULT_EXPORT_PATH}

  --mount-point <path>     Mount point on the client
                           Default: ${DEFAULT_MOUNT_POINT}

  --uid <uid>              Ownership UID for the exported storage
                           Default: ${DEFAULT_OWNER_UID}

  --gid <gid>              Ownership GID for the exported storage
                           Default: ${DEFAULT_OWNER_GID}

General:
  --verbose                Enable verbose output
  --help                   Show this help text

Examples:
  ${script_name} --server --setup
  ${script_name} --server --setup-daemon --reload
  ${script_name} --client --setup
  ${script_name} --client --setup-daemon --reload
  ${script_name} --client --server-ip 192.168.1.201 --setup-daemon --reload

What this script does:
  Server:
    * installs nfs-kernel-server
    * writes ${SERVER_EXPORTS_FILE}
    * ensures ownership on the export path
    * reloads the NFS export configuration

  Client:
    * installs nfs-common
    * writes systemd mount, automount, retry service, and retry timer units
    * enables automount and retry timer
    * reloads systemd
EOF
}

###############################################################################
# Argument parsing
###############################################################################

require_value() {
  local option="${1:-}"
  local value="${2:-}"

  if [[ -z "${value}" ]]; then
    die "Missing value for ${option}"
  fi
}

parse_args() {
  if [[ "$#" -eq 0 ]]; then
    show_help
    exit 0
  fi

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --server)
        ROLE="server"
        ;;
      --client)
        ROLE="client"
        ;;
      --setup)
        DO_SETUP="true"
        ;;
      --setup-daemon)
        DO_SETUP_DAEMON="true"
        ;;
      --reload)
        DO_RELOAD="true"
        ;;
      --server-ip)
        require_value "$1" "${2:-}"
        SERVER_IP="$2"
        shift
        ;;
      --allowed-network)
        require_value "$1" "${2:-}"
        ALLOWED_NETWORK="$2"
        shift
        ;;
      --export-path)
        require_value "$1" "${2:-}"
        EXPORT_PATH="$2"
        shift
        ;;
      --mount-point)
        require_value "$1" "${2:-}"
        MOUNT_POINT="$2"
        shift
        ;;
      --uid)
        require_value "$1" "${2:-}"
        OWNER_UID="$2"
        shift
        ;;
      --gid)
        require_value "$1" "${2:-}"
        OWNER_GID="$2"
        shift
        ;;
      --verbose)
        VERBOSE="true"
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
    shift
  done

  if [[ -z "${ROLE}" ]]; then
    die "You must specify either --server or --client"
  fi

  if [[ "${DO_SETUP}" == "false" && "${DO_SETUP_DAEMON}" == "false" && "${DO_RELOAD}" == "false" ]]; then
    die "No action selected. Use one or more of: --setup, --setup-daemon, --reload"
  fi
}

###############################################################################
# Validation
###############################################################################

validate_mount_point_name() {
  if [[ "${MOUNT_POINT}" != "/mnt/storage" ]]; then
    log_warn "The client unit filenames are hard-coded for /mnt/storage."
    log_warn "If you change --mount-point, also adjust the unit filenames in this script."
    die "Unsupported mount point for this script version: ${MOUNT_POINT}"
  fi
}

validate_role_requirements() {
  case "${ROLE}" in
    server)
      ;;
    client)
      validate_mount_point_name
      ;;
    *)
      die "Invalid role: ${ROLE}"
      ;;
  esac
}

###############################################################################
# File writers
###############################################################################

write_file_with_sudo() {
  local destination="${1}"
  local content="${2}"

  log_verbose "Writing file: ${destination}"
  printf '%s\n' "${content}" | sudo tee "${destination}" >/dev/null
}

###############################################################################
# Server tasks
###############################################################################

server_setup_packages() {
  log_info "Installing NFS server packages"
  sudo apt update
  sudo apt install -y nfs-kernel-server
}

server_setup_daemon() {
  log_info "Creating export path if needed: ${EXPORT_PATH}"
  sudo mkdir -p "${EXPORT_PATH}"

  log_info "Setting ownership on export path to ${OWNER_UID}:${OWNER_GID}"
  sudo chown -R "${OWNER_UID}:${OWNER_GID}" "${EXPORT_PATH}"

  log_info "Writing NFS export file: ${SERVER_EXPORTS_FILE}"
  local exports_content
  exports_content=$(cat <<EOF
${EXPORT_PATH} ${ALLOWED_NETWORK}(rw,sync,no_subtree_check)
EOF
)
  write_file_with_sudo "${SERVER_EXPORTS_FILE}" "${exports_content}"
}

server_reload() {
  log_info "Reloading NFS export configuration"
  sudo exportfs -ra

  log_info "Restarting NFS server"
  sudo systemctl restart nfs-kernel-server

  log_info "Current exports"
  sudo exportfs -v
}

###############################################################################
# Client tasks
###############################################################################

client_setup_packages() {
  log_info "Installing NFS client packages"
  sudo apt update
  sudo apt install -y nfs-common
}

client_setup_daemon() {
  log_info "Creating mount point if needed: ${MOUNT_POINT}"
  sudo mkdir -p "${MOUNT_POINT}"

  log_info "Setting ownership on mount point to ${OWNER_UID}:${OWNER_GID}"
  sudo chown "${OWNER_UID}:${OWNER_GID}" "${MOUNT_POINT}"

  log_info "Writing systemd mount unit: ${CLIENT_MOUNT_UNIT}"
  local mount_content
  mount_content=$(cat <<EOF
[Unit]
Description=NFS storage from locutus
Wants=network-online.target
After=network-online.target

[Mount]
What=${SERVER_IP}:${EXPORT_PATH}
Where=${MOUNT_POINT}
Type=nfs
Options=rw,_netdev,nofail,noatime,nfsvers=4.2
TimeoutSec=15

[Install]
WantedBy=multi-user.target
EOF
)
  write_file_with_sudo "${CLIENT_MOUNT_UNIT}" "${mount_content}"

  log_info "Writing systemd automount unit: ${CLIENT_AUTOMOUNT_UNIT}"
  local automount_content
  automount_content=$(cat <<EOF
[Unit]
Description=Automount NFS storage from locutus

[Automount]
Where=${MOUNT_POINT}
TimeoutIdleSec=10min

[Install]
WantedBy=multi-user.target
EOF
)
  write_file_with_sudo "${CLIENT_AUTOMOUNT_UNIT}" "${automount_content}"

  log_info "Writing retry service unit: ${CLIENT_RETRY_SERVICE}"
  local retry_service_content
  retry_service_content=$(cat <<EOF
[Unit]
Description=Retry NFS mount for ${MOUNT_POINT}
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl start mnt-storage.mount
EOF
)
  write_file_with_sudo "${CLIENT_RETRY_SERVICE}" "${retry_service_content}"

  log_info "Writing retry timer unit: ${CLIENT_RETRY_TIMER}"
  local retry_timer_content
  retry_timer_content=$(cat <<EOF
[Unit]
Description=Retry NFS mount for ${MOUNT_POINT} after boot

[Timer]
OnBootSec=2min
OnUnitInactiveSec=3min
Unit=mnt-storage-retry.service

[Install]
WantedBy=timers.target
EOF
)
  write_file_with_sudo "${CLIENT_RETRY_TIMER}" "${retry_timer_content}"
}

client_reload() {
  log_info "Reloading systemd daemon"
  sudo systemctl daemon-reload

  log_info "Enabling and starting automount unit"
  sudo systemctl enable --now mnt-storage.automount

  log_info "Enabling and starting retry timer"
  sudo systemctl enable --now mnt-storage-retry.timer

  log_info "Current unit status"
  sudo systemctl --no-pager --full status mnt-storage.automount || true
  sudo systemctl --no-pager --full status mnt-storage-retry.timer || true
}

###############################################################################
# Role dispatch
###############################################################################

run_server_tasks() {
  if [[ "${DO_SETUP}" == "true" ]]; then
    server_setup_packages
  fi

  if [[ "${DO_SETUP_DAEMON}" == "true" ]]; then
    server_setup_daemon
  fi

  if [[ "${DO_RELOAD}" == "true" ]]; then
    server_reload
  fi
}

run_client_tasks() {
  if [[ "${DO_SETUP}" == "true" ]]; then
    client_setup_packages
  fi

  if [[ "${DO_SETUP_DAEMON}" == "true" ]]; then
    client_setup_daemon
  fi

  if [[ "${DO_RELOAD}" == "true" ]]; then
    client_reload
  fi
}

###############################################################################
# Main
###############################################################################

main() {
  parse_args "$@"
  validate_role_requirements

  log_verbose "ROLE=${ROLE}"
  log_verbose "DO_SETUP=${DO_SETUP}"
  log_verbose "DO_SETUP_DAEMON=${DO_SETUP_DAEMON}"
  log_verbose "DO_RELOAD=${DO_RELOAD}"
  log_verbose "SERVER_IP=${SERVER_IP}"
  log_verbose "ALLOWED_NETWORK=${ALLOWED_NETWORK}"
  log_verbose "EXPORT_PATH=${EXPORT_PATH}"
  log_verbose "MOUNT_POINT=${MOUNT_POINT}"
  log_verbose "OWNER_UID=${OWNER_UID}"
  log_verbose "OWNER_GID=${OWNER_GID}"

  case "${ROLE}" in
    server)
      run_server_tasks
      ;;
    client)
      run_client_tasks
      ;;
    *)
      die "Unsupported role: ${ROLE}"
      ;;
  esac

  log_info "Done"
}

main "$@"