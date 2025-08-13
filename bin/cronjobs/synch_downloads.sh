#!/bin/bash
set -euo pipefail

# Only run on host 'donald'
current_host=$(hostname -s)
if [[ "$current_host" != "donald" ]]; then
  # echo "This script runs only on host 'donald'. Current host is '$current_host'. Exiting."
  exit 0
fi

# Proceed with rsync only if hostname match
rsync -rztv \
  patrick@192.168.1.201:/home/patrick/Downloads/ \
  /home/patrick/Downloads/Unkle \
  --exclude '.incoming' \
  --delete
