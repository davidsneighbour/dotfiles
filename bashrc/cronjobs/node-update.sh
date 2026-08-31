#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CRON_SCRIPT="${DOTFILES_ROOT}/configs/system/npm/cron-node-update.sh"

if [[ ! -x "${CRON_SCRIPT}" ]]; then
  printf '[error] Cron script is not executable: %s\n' "${CRON_SCRIPT}" >&2
  exit 1
fi

exec "${CRON_SCRIPT}" "$@"
