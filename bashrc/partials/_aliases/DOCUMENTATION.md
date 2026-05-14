# bashrc/partials/_aliases documentation

Files in this folder are shell-definition fragments sourced by `partials/aliases` through `dnb_auto_source`. They must be sourced, not executed.

## Files

### `folderwork`

Currently contains only shellcheck metadata. It defines no aliases or functions.

### `git`

Defines Git status shortcuts:

* `gits` — `git status --ignore-submodules --long --show-stash --ahead-behind --column`.
* `gitst` — `git status --short | grep '^[AMDRC]'`; shows changed paths with selected status letters.

Requirements: `git` and `grep`.

### `integrated`

Currently contains only shellcheck metadata. It defines no aliases or functions.

### `media`

Currently contains only shellcheck metadata. It defines no aliases or functions.

### `system`

Defines system information and safer file-operation aliases:

* `sysinfo` — `inxi -Sxxx`.
* `sysinfo-full` — `inxi -Fxxxz`.
* `sysinfo-cpu` — `inxi -Cxxx`.
* `sysinfo-gpu` — `inxi -Gxxx`.
* `sysinfo-mem` — `inxi -mxxx`.
* `mv` — `mv -iv`, interactive and verbose.
* `cp` — `cp -iv`, interactive and verbose.

Requirements: `inxi`, GNU/coreutils `mv`, and GNU/coreutils `cp`.

### `tools`

Defines tooling aliases:

* `codex-update` — `npm install --global @openai/codex@latest`.

Requirements: `npm` and network access to the npm registry when updating.

### `workspace`

Defines an interactive shell function:

* `actions "$@"` — delegates to `${HOME}/.dotfiles/bashrc/helpers/_actions/actions.sh`.

Requirements: Bash and an executable `bashrc/helpers/_actions/actions.sh` helper. The delegated helper options are documented in [`../../helpers/_actions/DOCUMENTATION.md`](../../helpers/_actions/DOCUMENTATION.md).
