# `docker/` documentation

This file documents every file currently present in `bashrc/helpers/docker`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Existing markdown references

* [`README.md`](./README.md)

## Files

### `docker/README.md`

Existing Docker backup runner guide; documents backup task formats and examples.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `docker/backup-runner.ts`

Executable TypeScript orchestrator for the Docker backup runner. Runs directly via Node.js 22+ (`--experimental-strip-types` shebang). Install as `backup-runner` (drop the extension) on target hosts.

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
* `formatConfigField`
* `asConfigRecord`
* `readOptionalBoolean`
* `readOptionalNumber`
* `readOptionalString`
* `readOptionalStringArray`
* `toBackupTomlConfig`
* `parseBackupTomlConfig`
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
* `isMainModule`

Requirements:

* Node.js 22+ (for `--experimental-strip-types` TypeScript execution).
* docker and Docker Compose for compose-copy tasks.
* tar for archives.

### `docker/tests/backup-runner-config-test.ts`

Fixture-backed parser checks for `backup.toml` configuration files. The tests cover valid configs, missing optional keys, empty strings, invalid TOML, and invalid field types.

### `docker/tests/fixtures/backup-empty-strings.toml`

Parser fixture proving that zero-length TOML strings stay distinct from missing values.

### `docker/tests/fixtures/backup-invalid-data-paths.toml`

Parser fixture proving that `data_paths` must contain strings only.

### `docker/tests/fixtures/backup-invalid.toml`

Parser fixture for invalid TOML syntax.

### `docker/tests/fixtures/backup-missing-keys.toml`

Parser fixture proving that optional fields can be omitted and handled by runtime defaults.

### `docker/tests/fixtures/backup-valid.toml`

Parser fixture covering a complete built-in backup task configuration.
