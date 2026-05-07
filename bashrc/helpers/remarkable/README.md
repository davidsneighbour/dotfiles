# transfer-remarkable

Transfer PDF and EPUB documents to and from a reMarkable tablet over SSH.

The tool supports three main workflows:

* Upload local PDF/EPUB files to the tablet.
* Download readable PDF/EPUB files from the tablet using their human document names.
* Create a raw rsync backup of the tablet's xochitl document directory.

## Requirements

You need SSH access to the tablet.

A typical `~/.ssh/config` entry looks like this:

```sshconfig
Host remarkable
  Hostname 10.11.99.1
  User root
  ForwardX11 no
  ForwardAgent no
```

You should configure SSH key authentication so the commands do not require a password.

The following local commands are required:

* `ssh`
* `scp`
* `rsync`, only for `raw-backup`

## Installation

Run the script directly during development:

```bash
node transfer-remarkable.ts --help
```

For a global CLI package, expose the script through `package.json`:

```json
{
  "name": "@davidsneighbour/transfer-remarkable",
  "version": "0.1.0",
  "type": "module",
  "bin": {
    "transfer-remarkable": "./dist/transfer-remarkable.js"
  },
  "scripts": {
    "build": "tsc"
  }
}
```

## Environment variables

### `REMARKABLE_HOST`

SSH host alias for the tablet.

Default:

```bash
remarkable
```

Example:

```bash
REMARKABLE_HOST=remarkable transfer-remarkable --file ./document.pdf
```

### `REMARKABLE_XOCHITL_DIR`

Remote xochitl document directory.

Default:

```bash
.local/share/remarkable/xochitl/
```

Example:

```bash
REMARKABLE_XOCHITL_DIR=.local/share/remarkable/xochitl/ transfer-remarkable backup
```

### `RESTART_XOCHITL_DEFAULT`

Controls whether xochitl is restarted after uploads.

Default:

```bash
0
```

Accepted values:

* `1`
* `0`
* `true`
* `false`

Example:

```bash
RESTART_XOCHITL_DEFAULT=1 transfer-remarkable --file ./document.pdf
```

## Upload files to the tablet

Upload is the default direction.

```bash
transfer-remarkable --file ./document.pdf
```

This is the same as:

```bash
transfer-remarkable --up --file ./document.pdf
```

You can upload multiple files:

```bash
transfer-remarkable --file ./document.pdf --file ./book.epub
```

The original positional style also works:

```bash
transfer-remarkable ./document.pdf ./book.epub
```

Supported upload formats:

* PDF
* EPUB

The tool creates the UUID-based file group expected by reMarkable, copies it to the xochitl directory, and optionally restarts xochitl afterwards.

## Restart xochitl after upload

The reMarkable UI may not show newly uploaded files until xochitl scans the document directory again.

Restart xochitl for a single upload:

```bash
transfer-remarkable --restart --file ./document.pdf
```

Short option:

```bash
transfer-remarkable -r ./document.pdf
```

The `--restart` option toggles the default.

If `RESTART_XOCHITL_DEFAULT=0`, `--restart` enables restart.

If `RESTART_XOCHITL_DEFAULT=1`, `--restart` disables restart.

## Download files from the tablet

The tablet stores documents using UUID-based filenames.

The download mode reads the remote `*.metadata` files, extracts `visibleName`, checks whether a matching `<uuid>.pdf` or `<uuid>.epub` exists, and downloads the source file under a readable local filename.

Download all readable PDF/EPUB files:

```bash
transfer-remarkable --down --all --output-dir ./remarkable-downloads
```

Download documents whose visible name contains text:

```bash
transfer-remarkable --down --name "Invoice" --output-dir ./remarkable-downloads
```

Download one document by UUID:

```bash
transfer-remarkable --down --id 11111111-2222-3333-4444-555555555555 --output-dir ./remarkable-downloads
```

Include documents marked as deleted:

```bash
transfer-remarkable --down --all --include-deleted --output-dir ./remarkable-downloads
```

The downloader avoids overwriting files during the same run. If two documents have the same visible name, the second file gets a suffix such as `Document (2).pdf`.

## Lazy backup alias

The lazy alias is:

```bash
transfer-remarkable backup
```

It is equivalent to:

```bash
transfer-remarkable --down --all --output-dir ./remarkable
```

This creates a human-readable PDF/EPUB export in `./remarkable`.

Use this when you want normal files that are easy to browse locally.

## Raw xochitl backup

The raw backup mode copies the complete xochitl directory with `rsync`.

```bash
transfer-remarkable raw-backup
```

Default output directory:

```bash
./remarkable-xochitl-backup
```

Custom output directory:

```bash
transfer-remarkable raw-backup --output-dir ./backups/remarkable-xochitl
```

This is not a human-readable export. It preserves the UUID-based internal storage layout.

Use this before firmware updates, experiments, large imports, or manual xochitl file changes.

## Safe raw backup

The tablet UI can modify xochitl files while `rsync` is running.

For a safer raw backup, stop xochitl during the backup and start it again afterwards:

```bash
transfer-remarkable raw-backup --safe
```

This temporarily interrupts the tablet UI.

## Pruned raw backup

By default, raw backup does not delete local files that no longer exist on the tablet.

To make the local directory mirror the tablet directory exactly:

```bash
transfer-remarkable raw-backup --prune
```

This passes `--delete` to `rsync`.

Use this carefully. If the remote path is wrong or incomplete, `--delete` can remove local backup files.

Safe mirror backup:

```bash
transfer-remarkable raw-backup --safe --prune
```

## Human export vs raw backup

### `backup`

Use this for readable local PDF/EPUB files.

```bash
transfer-remarkable backup
```

Pros:

* Uses document names from metadata.
* Produces normal `.pdf` and `.epub` files.
* Easy to browse locally.

Limitations:

* Only downloads documents that have a source `.pdf` or `.epub` file.
* Does not fully export handwritten notebooks.
* Does not preserve the complete internal xochitl file group.

### `raw-backup`

Use this for a storage-level backup.

```bash
transfer-remarkable raw-backup --safe
```

Pros:

* Copies the complete xochitl document directory.
* Preserves UUID metadata, companion directories, annotations, thumbnails, notebooks, and related files.
* Better suited for restore experiments and pre-update backups.

Limitations:

* Not human-readable.
* Internal format may change between reMarkable software versions.
* Restore should be tested carefully.
* Live writes can happen unless `--safe` is used.

## Command reference

```bash
transfer-remarkable --help
```

Show help.

```bash
transfer-remarkable --file ./document.pdf
```

Upload one file.

```bash
transfer-remarkable --file ./document.pdf --file ./book.epub
```

Upload multiple files.

```bash
transfer-remarkable --restart --file ./document.pdf
```

Upload and toggle xochitl restart.

```bash
transfer-remarkable --down --all --output-dir ./remarkable-downloads
```

Download all readable PDF/EPUB files.

```bash
transfer-remarkable --down --name "Invoice" --output-dir ./remarkable-downloads
```

Download files by visible name match.

```bash
transfer-remarkable --down --id 11111111-2222-3333-4444-555555555555
```

Download one file by UUID.

```bash
transfer-remarkable backup
```

Lazy human-readable PDF/EPUB export to `./remarkable`.

```bash
transfer-remarkable raw-backup
```

Raw rsync backup to `./remarkable-xochitl-backup`.

```bash
transfer-remarkable raw-backup --safe
```

Raw rsync backup while xochitl is stopped.

```bash
transfer-remarkable raw-backup --safe --prune
```

Raw rsync mirror backup while xochitl is stopped.

## Notes

The upload mode creates the document files expected by reMarkable:

* `<uuid>.pdf` or `<uuid>.epub`
* `<uuid>.metadata`
* `<uuid>.content`
* `<uuid>.cache`, PDF only
* `<uuid>.highlights`, PDF only
* `<uuid>.thumbnails`, PDF only

The download mode uses metadata to map UUID filenames back to readable document names.

The raw backup mode does not rename anything. It intentionally preserves the tablet's internal file layout.
