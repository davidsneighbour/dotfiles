#!/bin/bash

# Configuration
SERVICE_FILE="/etc/systemd/system/pi-shutdown.service"
SCRIPT_FILE="/home/patrick/github.com/davidsneighbour/dotfiles/bin/helpers/shutdown-pi.sh"

# Create the systemd service file
echo "Creating systemd service file at ${SERVICE_FILE}..."
sudo bash -c "cat > ${SERVICE_FILE}" <<EOF
[Unit]
Description=Send shutdown command to Raspberry Pi
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=${SCRIPT_FILE}

[Install]
WantedBy=halt.target reboot.target
EOF
sudo chmod 644 "${SERVICE_FILE}"
sudo chown root:root "${SERVICE_FILE}"

# Reload systemd, enable, and start the service
echo "Reloading systemd and enabling the service..."
sudo systemctl daemon-reload
sudo systemctl enable pi-shutdown.service
sudo systemctl daemon-reload
systemctl status pi-shutdown.service
