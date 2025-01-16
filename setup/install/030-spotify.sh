#!/bin/bash

# Function to display help
function help() {
  echo "Usage: ${FUNCNAME[0]} --help"
  echo "This script installs Spotify on Debian-based systems."
}

# Exit on errors and pipe failures
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  help
  exit 0
fi

# Add Spotify GPG key and repository
curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | \
  sudo tee /usr/share/keyrings/spotify-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/spotify-archive-keyring.gpg] http://repository.spotify.com stable non-free" | \
  sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null

# Update and install Spotify
sudo apt update
sudo apt install -y spotify-client
