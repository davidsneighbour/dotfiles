# `logs/` documentation

This file documents every file currently present in `bashrc/helpers/logs`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Existing markdown references

* [`ToDo.md`](./ToDo.md)

## Files

### `logs/ToDo.md`

Backlog notes for the log cleanup helper.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `logs/cleanup.ts`

Config-driven log cleanup and archive helper.

CLI option notes:

* --config PATH — TOML config file.
* --log-root PATH — root log directory.
* --temp-root PATH — temporary work directory.
* --verbose — verbose output, also via DNB_VERBOSE.
* --dry-run — show without changing files.
* --help — show help.

Runtime state:

* The cleanup lock file is written below the configured temporary work
  directory, not below the log root.

Functions/methods defined:

* `printHelp`
* `consoleVerbose`
* `isVerboseEnv`
* `parseArgs`
* `ensureDir`
* `fileExists`
* `runCommand`
* `moveFile`
* `isCleanupAction`
* `validateConfig`
* `loadConfig`
* `toFolderSlug`
* `resolvePolicy`
* `deriveArchiveDay`
* `findLogCandidates`
* `walk`
* `writeTaskLog`
* `acquireLock`
* `releaseLock`
* `groupCandidatesForCompression`
* `archivePathFor`
* `ensureUniquePath`
* `deleteFiles`
* `compressGroup`
* `formatCurrentDay`
* `ensureBinaryAvailable`
* `main`

Requirements:

* Node.js/TypeScript runtime compatible with this repository's `.ts` helpers.
* Filesystem permissions for the configured log and temporary paths.
* `tar` and `xz` for compression actions.

### `logs/config.toml`

Default log cleanup configuration.

### `logs/log-cleanup.config.schema.json`

JSON Schema for logs/config.toml.
