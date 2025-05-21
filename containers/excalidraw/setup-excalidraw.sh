#!/bin/bash

# Setup script for Excalidraw systemd service
# Installs excalidraw.service into /etc/systemd/system/
# and enables/starts it with verbose CLI output

set -o errexit
set -o nounset
set -o pipefail

script_dir="${BASH_SOURCE[0]}"
script_dir="$(realpath "$(dirname "$script_dir")")"

service_name="excalidraw.service"
systemd_path="/etc/systemd/system/${service_name}"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_path="${script_dir}/backup-${service_name}.${timestamp}"

echo "👤 Running as: $(whoami)"
echo "🔐 Checking sudo access..."

if ! sudo -v; then
  echo "❌ This script requires sudo privileges. Aborting."
  exit 1
fi

echo "✅ Sudo access confirmed."
echo
echo "🔧 Setting up Excalidraw systemd service..."
echo "📁 Script directory: ${script_dir}"
echo "📄 Service file will be written to: ${systemd_path}"
echo

# Define the content of the systemd unit
service_unit="[Unit]
Description=Excalidraw web service
After=network.target

[Service]
Type=simple
User=patrick
WorkingDirectory=${script_dir}
ExecStart=/bin/bash -c '. $HOME/.nvm/nvm.sh && nvm use 20 && /home/patrick/github.com/davidsneighbour/pizen/excalidraw/start-excalidraw.sh'
Restart=on-failure
StartLimitBurst=5
StartLimitIntervalSec=60
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal
SyslogIdentifier=excalidraw

[Install]
WantedBy=multi-user.target"

# Check if service file already exists
if [[ -f "${systemd_path}" ]]; then
  echo "⚠️  ${service_name} already exists at ${systemd_path}"
  read -rp "❓ Overwrite existing service and continue? [y/N]: " confirm
  if [[ "${confirm}" != "y" ]]; then
    echo "❌ Setup aborted by user."
    exit 2
  fi
  echo "📦 Backing up existing service file to:"
  echo "   ${backup_path}"
  sudo cp "${systemd_path}" "${backup_path}" || {
    echo "❌ Failed to back up existing service file."
    exit 3
  }
fi

echo "📤 Writing service file to systemd directory..."
echo "${service_unit}" | sudo tee "${systemd_path}" > /dev/null || {
  echo "❌ Failed to write systemd unit file."
  exit 4
}

echo "🔄 Reloading systemd manager configuration..."
sudo systemctl daemon-reexec || {
  echo "❌ Failed daemon-reexec."
  exit 5
}
sudo systemctl daemon-reload || {
  echo "❌ Failed daemon-reload."
  exit 6
}

echo "🛠️  Enabling service to start on boot..."
sudo systemctl enable "${service_name}" || {
  echo "❌ Failed to enable service."
  exit 7
}

echo "🚀 Starting service now..."
sudo systemctl restart "${service_name}" || {
  echo "❌ Failed to start service."
  exit 8
}

echo
echo "✅ Service setup complete and running."

echo
echo "📡 You can check the status with:"
echo "    sudo systemctl status ${service_name}"
echo "🪵 View logs with:"
echo "    journalctl -u ${service_name} -n 50 -f"
