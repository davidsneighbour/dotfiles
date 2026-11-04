#!/bin/bash
set -euo pipefail
script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && builtin pwd -P)"
exec node "${script_dir}/dotfiles-config.ts" "$@"
