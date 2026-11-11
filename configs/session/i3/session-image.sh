#!/bin/bash
#
# Print the absolute path of a desktop session image that the central
# configuration defines (configs/dotfiles.json, `dotfiles.session.*`; see
# schema/README.md). This is the only place that reads these settings, so
# every consumer resolves paths the same way:
#
#   wallpaper   dotfiles.session.wallpaperImage   (i3 `feh --bg-fill` line in
#                                                   configs/session-starts.conf)
#   lockscreen  dotfiles.session.lockScreenImage  (lock.sh and
#                                                   ../lightdm/setup.sh)
#
# A relative value resolves from the repository root; an absolute value is
# used as is. There is no tilde or variable expansion (the schema rejects a
# leading `~`). The path goes to stdout. If the setting is missing, the
# configuration is invalid, or the file does not exist, a one-line error goes
# to stderr and the exit status is 1, so callers can fall back without an
# image.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

print_help() {
  cat <<EOF
Usage: $(basename "${0}") wallpaper|lockscreen
       $(basename "${0}") --help

Print the absolute path of the image that configs/dotfiles.json defines:
  wallpaper   dotfiles.session.wallpaperImage
  lockscreen  dotfiles.session.lockScreenImage

Relative paths resolve from the repository root:
  ${REPO_ROOT}

Exit status: 0 on success, 1 if the setting or the file is missing, 2 on
invalid arguments.
EOF
}

if [[ "${#}" -ne 1 ]]; then
  print_help >&2
  exit 2
fi

case "${1}" in
  --help)
    print_help
    exit 0
    ;;
  wallpaper)
    pointer='/dotfiles/session/wallpaperImage'
    ;;
  lockscreen)
    pointer='/dotfiles/session/lockScreenImage'
    ;;
  *)
    printf 'Unknown argument: %s\n\n' "${1}" >&2
    print_help >&2
    exit 2
    ;;
esac

# stderr is merged into the captured output: on success the CLI writes
# nothing to stderr, and on failure only its first line (the error, without
# the CLI's usage text) is reported.
if ! image="$("${REPO_ROOT}/scripts/dotfiles-config.sh" --action get --raw --pointer "${pointer}" 2>&1)"; then
  printf 'session-image.sh: cannot read %s: %s\n' "${pointer}" "${image%%$'\n'*}" >&2
  exit 1
fi

if [[ "${image}" != /* ]]; then
  image="${REPO_ROOT}/${image}"
fi

if [[ ! -f "${image}" ]]; then
  printf 'session-image.sh: image for %s not found: %s\n' "${pointer}" "${image}" >&2
  exit 1
fi

printf '%s\n' "${image}"
