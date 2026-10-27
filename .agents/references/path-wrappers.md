<!-- markdownlint-disable dnb-title-case-style -->

# PATH wrappers

A **PATH wrapper** is a small executable Bash script in a directory listed in Bash's `PATH`. In this repository, wrappers live in `bin/`, which the workstation already includes in `PATH`. Bash finds the wrapper by its command name; the wrapper finds and runs the actual script elsewhere in the repository. The caller does not need to know the target script's location or change directory.

Request this with: **Create a PATH wrapper for `<script>` as `<command>`.** For example: "Create a PATH wrapper for `configs/session/storage/gdrive-mounts.sh` as `gdrive-mount`." The existing [`bin/gdrive-mount`](../../bin/gdrive-mount) is an example.

## Procedure

1. Read the applicable [Bash](../instructions/bashrc/bashrc.instructions.md) and [CLI](../instructions/cli.instructions.md) rules, the target script, and its folder documentation. Confirm that the script is a standalone command. Scripts that must change the caller's shell state need a sourced function or alias instead.
2. Choose a short, extensionless command name. Check `type -a <command>` and existing `bin/` entries for conflicts. If no name was requested, use the target basename without its extension. Resolve a conflict before replacing or shadowing an existing command.
3. Create `bin/<command>` using the template below. Resolve the repository relative to the wrapper rather than the caller's working directory or a hard-coded checkout path. Keep the actual behaviour in the target script.
4. Select the final `exec` line for the target's runtime. Forward arguments with `"$@"` to preserve spaces and argument boundaries. `exec` replaces the wrapper process, preserving the target's exit status and normal signal handling.
5. Run `chmod +x bin/<command>`. Update the target folder's README with the command, examples, and no-argument behaviour.
6. Verify the wrapper as described below, then run `npm run check`. Report any blocked or failing checks accurately.

## Bash wrapper template

Replace `path/to/script.sh` with the target path relative to the repository root.

```bash
#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET="${DOTFILES_ROOT}/path/to/script.sh"

if [[ ${#} -eq 0 ]]; then
  set -- --help
fi

if [[ ! -f "${TARGET}" || ! -r "${TARGET}" ]]; then
  printf 'Error: target script is missing or unreadable: %s\n' "${TARGET}" >&2
  printf 'Usage: %s [options]\nRun with --help after restoring the target script.\n' "${0##*/}" >&2
  exit 1
fi

exec /bin/bash "${TARGET}" "$@"
```

The explicit Bash interpreter does not require the target file to be executable. If the existing target is executable and has the correct shebang, `exec "${TARGET}" "$@"` follows the existing `bin/` convention too.

The CLI rules require help when a helper command receives no arguments. The template therefore forwards `--help` in that case. Ensure that the target supports `--help`, named flags, and `--verbose`. Delegate these options to the target rather than copying its parser or help text into the wrapper. Document an explicit option for running the default action, as with `gdrive-mount --verbose`.

The template assumes the wrapper is stored directly in the repository's `bin/` directory. Do not symlink the wrapper into a different directory without adapting and verifying path resolution.

## Node targets

Use the same Bash wrapper with the correct `TARGET`, replacing the final `exec` line with:

```bash
if ! command -v node >/dev/null 2>&1; then
  printf 'Error: node is not on PATH; load the configured Node environment and retry.\n' >&2
  printf 'Usage: %s [options]\nRun with --help once Node is available.\n' "${0##*/}" >&2
  exit 1
fi

exec node "${TARGET}" "$@"
```

Use the project's existing ESM entry point and supported Node runtime. For TypeScript, reuse the target's established executable entry point or required Node options; do not assume that every TypeScript script runs directly in Node. Keep runtime options before `"${TARGET}"`. Do not install packages, invoke `npx`, or pin a workstation-specific Node installation path inside the wrapper.

## Verification

Run `bash -n bin/<command>` and `shellcheck bin/<command>`. From a directory outside the repository, use `type -a <command>` and `<command> --help` to confirm Bash finds the expected wrapper through `PATH`. Compare its no-argument output with its help output. Verify argument forwarding and non-zero exit propagation with a harmless target option or a temporary fixture when needed; do not trigger mounts, authorisation, or other operational actions merely to test dispatch.

If Bash cannot find the wrapper, inspect `printf '%s\n' "${PATH}"` and the existing workstation PATH configuration. The repository's `bin/` directory must be an entry in `PATH`; the target script's directory does not need to be. Do not add duplicate PATH entries or create another copy of the target script. If the wrapper resolves to the wrong file, inspect aliases, functions, and other commands with `type -a`, and use `hash -r` after correcting a cached command path.
