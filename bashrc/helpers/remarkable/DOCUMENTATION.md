# `remarkable/` documentation

This file documents every file currently present in `bashrc/helpers/remarkable`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Existing Markdown references

* [`README.md`](./README.md)

## Files

### `remarkable/README.md`

Existing user guide for reMarkable transfers.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `remarkable/transfer.ts`

Transfers PDF/EPUB files to/from a reMarkable tablet and supports raw rsync backups.

CLI option notes:

* --up — upload local PDF/EPUB files; default direction.
* --down — download from tablet.
* --file PATH — upload file; repeatable and supports --file=PATH.
* --all — download all readable PDF/EPUB files.
* --name TEXT — download matching visibleName.
* --id UUID — download one document by UUID.
* --output-dir PATH — output directory for downloads/backups.
* --include-deleted — include deleted metadata.
* --restart, -r — toggle xochitl restart after upload.
* --safe — stop/start xochitl around raw backup.
* --prune — pass --delete to rsync for raw backup.
* --verbose — command details.
* --help, -h — show help.
* Aliases: backup, raw-backup.

Functions/methods defined:

* `printHelp`
* `parseBooleanEnv`
* `readOptionValue`
* `parseArguments`
* `createConfig`
* `validateConfig`
* `runCommand`
* `captureCommand`
* `getSupportedExtension`
* `createMetadata`
* `createContent`
* `prepareUploadDocument`
* `clearWorkDirectory`
* `uploadDocument`
* `uploadToRemarkable`
* `shellQuote`
* `isRecord`
* `parseRemoteMetadata`
* `sanitiseFileName`
* `remoteFileExists`
* `listDownloadableRemoteDocuments`
* `filterRemoteDocuments`
* `sortRemoteDocuments`
* `buildOutputPath`
* `downloadFromRemarkable`
* `rawBackupFromRemarkable`
* `run`
* `main`

Requirements:

* Node.js with TypeScript execution support.
* ssh and scp for transfers.
* rsync for raw-backup.
* SSH access to the reMarkable host.
