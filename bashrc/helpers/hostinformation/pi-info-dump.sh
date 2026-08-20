#!/bin/bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage:
  pi-info-dump --host HOSTNAME [options]

Collect hardware, OS, networking, storage, service, and Raspberry Pi
information from a remote host over SSH and save it to a local text file.

Options:
  --host HOSTNAME        SSH hostname or address. Required.
  --user USER            SSH user. Default: patrick
  --output-dir DIR       Directory for output files. Default: current directory
  --ssh-option OPTION    Additional ssh option. May be specified multiple times.
  --help                 Show this help.

Examples:
  pi-info-dump --host hal2026
  pi-info-dump --host hal2025.local
  pi-info-dump --host 192.168.1.21 --user patrick
  pi-info-dump --host hal2025 --output-dir ~/pi-info
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

main() {
  local host=""
  local user="patrick"
  local output_dir="."
  local -a ssh_options=()

  while (($#)); do
    case "$1" in
    --host)
      [[ $# -ge 2 ]] || die "--host requires a value"
      host="$2"
      shift 2
      ;;
    --user)
      [[ $# -ge 2 ]] || die "--user requires a value"
      user="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || die "--output-dir requires a value"
      output_dir="$2"
      shift 2
      ;;
    --ssh-option)
      [[ $# -ge 2 ]] || die "--ssh-option requires a value"
      ssh_options+=("-o" "$2")
      shift 2
      ;;
    --help)
      usage
      return 0
      ;;
    *)
      die "Unknown option: $1. Use --help for usage."
      ;;
    esac
  done

  [[ -n "${host}" ]] || die "--host is required"

  command -v ssh >/dev/null 2>&1 || die "ssh is not installed"

  mkdir -p "${output_dir}"

  local timestamp
  timestamp="$(date '+%Y%m%d-%H%M%S')"

  local safe_host
  safe_host="${host//[^a-zA-Z0-9._-]/_}"

  local output_file
  output_file="${output_dir%/}/${safe_host}-${timestamp}.txt"

  printf 'Collecting Pi information from %s@%s...\n' "${user}" "${host}"

  if ! ssh "${ssh_options[@]}" "${user}@${host}" 'bash -s' >"${output_file}" <<'REMOTE_SCRIPT'; then
set -u

run() {
    local description="$1"
    local command="$2"

    printf '\n'
    printf '###############################################################################\n'
    printf '# %s\n' "$description"
    printf '# Command: %s\n' "$command"
    printf '###############################################################################\n'

    bash -c "$command" 2>&1 || {
        local status=$?
        printf '# Command exited with status %d\n' "$status"
        return 0
    }
}

printf '# Raspberry Pi information dump\n'
printf '# Generated: %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
printf '# Host: %s\n' "$(hostname 2>/dev/null || printf 'unknown')"
printf '# Generated remotely through SSH\n'

run \
    'System identity' \
    'hostnamectl'

run \
    'Raspberry Pi board model' \
    'cat /sys/firmware/devicetree/base/model 2>/dev/null; echo'

run \
    'Raspberry Pi board revision and model' \
    "grep -E '^(Model|Revision)' /proc/cpuinfo"

run \
    'Kernel information' \
    'uname -a'

run \
    'Machine architecture' \
    'uname -m'

run \
    'CPU information' \
    'lscpu'

run \
    'Memory usage' \
    'free -h'

run \
    'Physical memory total' \
    'grep MemTotal /proc/meminfo'

run \
    'Operating system information' \
    'cat /etc/os-release'

run \
    'Block devices and storage models' \
    'lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS,MODEL'

run \
    'Mounted filesystem usage' \
    'df -hT'

run \
    'Network addresses' \
    'ip -brief address'

run \
    'Network interfaces and MAC addresses' \
    'ip -brief link'

run \
    'NetworkManager device state' \
    'nmcli device status'

run \
    'NetworkManager connections' \
    'nmcli connection show'

run \
    'Routing table' \
    'ip route'

run \
    'DNS configuration' \
    'resolvectl status 2>/dev/null || true'

run \
    'System time and timezone' \
    'timedatectl'

run \
    'SSH service enabled state' \
    'systemctl is-enabled ssh 2>&1 || true'

run \
    'SSH service active state' \
    'systemctl is-active ssh 2>&1 || true'

run \
    'Current user identity and groups' \
    'id; groups'

run \
    'Docker version' \
    'docker --version 2>/dev/null || true'

run \
    'Docker containers' \
    'docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true'

run \
    'Docker networks' \
    'docker network ls 2>/dev/null || true'

run \
    'Tailscale status' \
    'tailscale status 2>/dev/null || true'

run \
    'Tailscale IP addresses' \
    'tailscale ip 2>/dev/null || true'

run \
    'Raspberry Pi firmware version' \
    'sudo -n vcgencmd version 2>/dev/null || vcgencmd version 2>/dev/null || true'

run \
    'Raspberry Pi throttling and undervoltage state' \
    'sudo -n vcgencmd get_throttled 2>/dev/null || vcgencmd get_throttled 2>/dev/null || true'

run \
    'Raspberry Pi temperature' \
    'sudo -n vcgencmd measure_temp 2>/dev/null || vcgencmd measure_temp 2>/dev/null || true'

run \
    'Failed systemd services' \
    'systemctl --failed --no-pager'

run \
    'System uptime and load' \
    'uptime'

printf '\n'
printf '# End of Raspberry Pi information dump\n'
REMOTE_SCRIPT
    rm -f "${output_file}"
    die "Failed to collect information from ${user}@${host}"
  fi

  printf 'Saved: %s\n' "${output_file}"
}

main "$@"
