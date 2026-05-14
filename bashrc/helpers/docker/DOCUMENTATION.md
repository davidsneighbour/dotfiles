# `docker/` documentation

This file documents every file currently present in `bashrc/helpers/docker`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Existing Markdown references

* [`README.md`](./README.md)

## Files

### `docker/README.md`

Existing Docker backup runner guide; documents backup task formats and examples.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `docker/backup-runner`

Executable wrapper/source for the Docker backup runner.

CLI option notes:

* --root PATH — root directory to scan recursively.
* --destination PATH — directory for backup archives.
* --after-each-command CMD — hook after each successful archive.
* --after-all-command CMD — hook after all backups succeed.
* --dry-run — preview work.
* --verbose — debug output.
* --stop-on-error — stop at first failure.
* --help — show help.

Functions/methods defined:

* `printHelp`
* `parseArgs`
* `log`
* `pathExists`
* `ensureDirectory`
* `isExecutable`
* `safeName`
* `createTimestamp`
* `interpolate`
* `execCommand`
* `findTasks`
* `walk`
* `parseTomlValue`
* `setNestedValue`
* `parseToml`
* `toBackupTomlConfig`
* `detectComposeCommand`
* `shellQuote`
* `createTarGzFromPaths`
* `createTarGzFromDirectory`
* `executeTomlTask`
* `detectScriptType`
* `executeScriptTask`
* `runAfterCommand`
* `getHostName`
* `validateRootDirectory`
* `printSummary`
* `main`

Requirements:

* Node.js.
* docker and Docker Compose for compose-copy tasks.
* tar for archives.

### `docker/backup-runner.mjs`

JavaScript copy of the Docker backup runner source.

CLI option notes:

* --root PATH — root directory to scan recursively.
* --destination PATH — directory for backup archives.
* --after-each-command CMD — hook after each successful archive.
* --after-all-command CMD — hook after all backups succeed.
* --dry-run — preview work.
* --verbose — debug output.
* --stop-on-error — stop at first failure.
* --help — show help.

Functions/methods defined:

* `printHelp`
* `parseArgs`
* `log`
* `pathExists`
* `ensureDirectory`
* `isExecutable`
* `safeName`
* `createTimestamp`
* `interpolate`
* `execCommand`
* `findTasks`
* `walk`
* `parseTomlValue`
* `setNestedValue`
* `parseToml`
* `toBackupTomlConfig`
* `detectComposeCommand`
* `shellQuote`
* `createTarGzFromPaths`
* `createTarGzFromDirectory`
* `executeTomlTask`
* `detectScriptType`
* `executeScriptTask`
* `runAfterCommand`
* `getHostName`
* `validateRootDirectory`
* `printSummary`
* `main`

Requirements:

* Node.js.
* docker and Docker Compose for compose-copy tasks.
* tar for archives.

### `docker/backup-runner.ts`

TypeScript source for the Docker backup runner.

CLI option notes:

* --root PATH — root directory to scan recursively.
* --destination PATH — directory for backup archives.
* --after-each-command CMD — hook after each successful archive.
* --after-all-command CMD — hook after all backups succeed.
* --dry-run — preview work.
* --verbose — debug output.
* --stop-on-error — stop at first failure.
* --help — show help.

Functions/methods defined:

* `printHelp`
* `parseArgs`
* `log`
* `pathExists`
* `ensureDirectory`
* `isExecutable`
* `safeName`
* `createTimestamp`
* `interpolate`
* `execCommand`
* `findTasks`
* `walk`
* `parseTomlValue`
* `setNestedValue`
* `parseToml`
* `toBackupTomlConfig`
* `detectComposeCommand`
* `createTarGzFromPaths`
* `createTarGzFromDirectory`
* `shellQuote`
* `executeTomlTask`
* `detectScriptType`
* `executeScriptTask`
* `runAfterCommand`
* `getHostName`
* `validateRootDirectory`
* `printSummary`
* `main`

Requirements:

* Node.js with TypeScript execution support for this source file.
* docker and Docker Compose for compose-copy tasks.
* tar for archives.
