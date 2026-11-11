#!/bin/bash
#
# Lock the i3 session with i3lock, using this directory's lockscreen image
# and the Dracula Pro Nosferatu i3lock-colour theme when the local binary supports it.
#
# Prefers `i3lock-color` (installed under that name in /usr/local/bin, see
# SESSION.md, "Screen lock") and falls back to the apt `i3lock`. The theme
# options exist only in i3lock-color; plain i3lock gets the image-only
# command and a warning on stderr (the xss-lock unit's journal).
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
#
# After i3lock exits (i.e. once the user has unlocked), this script restarts
# Polybar via launch.sh. Polybar sometimes fails to reappear after an
# unlock, leaving the bar missing until a manual i3 restart ($mod+Shift+R) —
# launch.sh's kill-existing-instance-then-relaunch logic is the fix, run
# unconditionally on every unlock since it is a no-op (from the user's
# perspective) when Polybar is already fine. This is why the script no
# longer `exec`s i3lock at the end: that would replace this process and
# leave nothing behind to run launch.sh afterwards.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCKSCREEN_IMAGE="${SCRIPT_DIR}/lockscreen.jpg"

select_locker() {
  local candidate
  for candidate in i3lock-color i3lock; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

# Neither i3lock nor i3lock-color lists its long options in `--help`, so
# detect i3lock-color by the copyright line of `--version`, which only the
# fork prints. The output is captured before matching: a `| grep -q` pipe
# under pipefail can report a false negative when grep exits early (SIGPIPE).
theme_supported() {
  local version_output
  # `|| :` because the exit status of `--version` is irrelevant; only the
  # text is checked.
  version_output="$("${locker}" --version 2>&1)" || :
  [[ "${version_output}" == *'Raymond Li'* || "${version_output}" == *'Cassandra Fox'* ]]
}

print_help() {
  cat <<EOF
Usage: $(basename "${0}") [--help]

Lock the screen via 'i3lock-color --nofork' (or 'i3lock --nofork' when
i3lock-color is not installed), using:
  ${LOCKSCREEN_IMAGE}

The Dracula theme, clock, indicator, and cover-fit image scaling (--fill)
need i3lock-color; plain i3lock shows only the unscaled image.

Restarts Polybar (via ../polybar/launch.sh) once the screen is unlocked.

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

if ! locker="$(select_locker)"; then
  printf 'lock.sh: neither i3lock-color nor i3lock found on PATH\n' >&2
  exit 1
fi

if [[ ! -f "${LOCKSCREEN_IMAGE}" ]]; then
  printf 'lock.sh: lockscreen image not found: %s\n' "${LOCKSCREEN_IMAGE}" >&2
  exit 1
fi

args=(
  --nofork
  -i "${LOCKSCREEN_IMAGE}"
)

if theme_supported; then
  alpha='dd'
  # Dracula Pro Nosferatu named colours (see docs/colours.md).
  background='#17191B'
  selection='#2E3236'
  red='#FF7D6C'
  pink='#EE9440'
  comment='#9EA4AC'
  green='#D0DBC4'
  orange='#C9A273'

  args+=(
    # Scale the image to cover each screen, cropping the overflowing side
    # (CSS `object-fit: cover`). Without it, i3lock draws the image at its
    # native size from the top-left corner.
    --fill
    --insidever-color="${selection}${alpha}"
    --insidewrong-color="${selection}${alpha}"
    --inside-color="${selection}${alpha}"
    --ringver-color="${green}${alpha}"
    --ringwrong-color="${red}${alpha}"
    --ring-color="${comment}${alpha}"
    --line-uses-ring
    --keyhl-color="${pink}${alpha}"
    --bshl-color="${orange}${alpha}"
    --separator-color="${selection}${alpha}"
    --verif-color="${green}"
    --wrong-color="${red}"
    --modif-color="${red}"
    --layout-color="${comment}"
    --date-color="${comment}"
    --time-color="${comment}"
    --screen=1
    --blur=1
    --clock
    --indicator
    --time-str='%H:%M:%S'
    --date-str='%A %e %B %Y'
    --verif-text='Checking...'
    --wrong-text='Wrong password'
    --noinput-text='No input'
    --lock-text='Locking...'
    --lockfailed-text='Lock failed'
    --radius=200
    --ring-width=20
    --pass-media-keys
    --pass-screen-keys
    --pass-volume-keys
    --color="${background#'#'}"
  )
else
  printf 'lock.sh: %s is not i3lock-color; locking without the theme (see SESSION.md, "Screen lock")\n' "${locker}" >&2
fi

status=0
"${locker}" "${args[@]}" || status="${?}"

"${SCRIPT_DIR}/../polybar/launch.sh" || true

exit "${status}"
