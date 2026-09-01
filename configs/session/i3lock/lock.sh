#!/bin/bash
#
# Lock the i3 session with i3lock, using this directory's lockscreen image.
#
# This is the locker xss-lock runs (started via
# configs/session/i3/configs/session-starts.conf), which xss-lock invokes
# both for $mod+L (via `loginctl lock-session`, see
# configs/session/i3/configs/keybindings.conf) and automatically before the
# system suspends. Resolves its own path so it works regardless of the
# caller's working directory — i3's `exec` runs commands from i3's own
# environment (plain, non-interactive, non-login shell), not a shell that
# has cd'd into the repo.
#
# --nofork is required: xss-lock waits for the locker process to exit to
# know the screen is locked/unlocked, but i3lock daemonises (forks into the
# background and the parent exits immediately) unless told not to — without
# --nofork, xss-lock would think the lock ended the instant i3lock forked,
# not when the user actually unlocked it (see `man i3lock`, "RECOMMENDED
# USAGE").

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCKSCREEN_IMAGE="${SCRIPT_DIR}/lockscreen.png"

print_help() {
  cat <<EOF
Usage: $(basename "${0}") [--help]

Lock the screen via 'i3lock --nofork', using:
  ${LOCKSCREEN_IMAGE}

Intended as the locker for xss-lock (see
configs/session/i3/configs/session-starts.conf), not for direct interactive
use, though running it directly also works.

Options:
  --help   Show this help and exit.
EOF
}

if [[ "${1:-}" == "--help" ]]; then
  print_help
  exit 0
fi

if [[ "${#}" -gt 0 ]]; then
  printf 'Unknown argument: %s\n\n' "${1}" >&2
  print_help >&2
  exit 2
fi

if ! command -v i3lock >/dev/null 2>&1; then
  printf 'lock.sh: i3lock executable not found on PATH\n' >&2
  exit 1
fi

if [[ ! -f "${LOCKSCREEN_IMAGE}" ]]; then
  printf 'lock.sh: lockscreen image not found: %s\n' "${LOCKSCREEN_IMAGE}" >&2
  exit 1
fi

exec i3lock --nofork -i "${LOCKSCREEN_IMAGE}"
