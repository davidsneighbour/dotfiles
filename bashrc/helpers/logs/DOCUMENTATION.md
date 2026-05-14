# `logs/` documentation

This file documents every file currently present in `bashrc/helpers/logs`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Existing Markdown references

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

### `logs/config.toml`

Default log cleanup configuration.

### `logs/log-cleanup.config.schema.json`

JSON Schema for logs/config.toml.

# bashrc/helpers/logs documentation

This folder contains log-cleanup configuration and a TypeScript cleanup helper.

## `cleanup.ts`

TypeScript helper that scans configured log directories, groups old log files, optionally compresses/deletes them, and reports cleanup actions.

CLI option notes: inspect `cleanup.ts --help` through the repository TypeScript runner before use; the implementation is the source of truth for accepted options.

Important functions/methods implemented in the file include configuration loading, path expansion, candidate grouping, compression, deletion, and reporting helpers.

Requirements: Node.js/TypeScript runtime compatible with this repository's `.ts` helpers, filesystem permissions for configured log paths, and compression tools/libraries used by the implementation.

## `config.toml`

Default TOML configuration for log cleanup. It defines cleanup targets and retention/compression behaviour consumed by `cleanup.ts`.

## `log-cleanup.config.schema.json`

JSON schema for validating `config.toml` in schema-aware editors or validation tooling.

## `ToDo.md`

One-line planning note for future log helper work. It is not executable and does not define current behaviour.
