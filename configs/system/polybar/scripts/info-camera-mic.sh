#!/bin/bash

set -euo pipefail

camera=""
mic=""

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: info-camera-mic.sh [--help]

Print Polybar camera and microphone indicators.
EOF
  exit 0
fi

if lsof /dev/video0 >/dev/null 2>&1; then
  camera="#1"
fi

if pacmd list-sources 2>&1 | grep -q RUNNING; then
  mic="#2"
fi

echo "${camera} ${mic}"
