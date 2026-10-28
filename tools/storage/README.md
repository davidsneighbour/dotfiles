# Storage search

Find a file or folder and list every indexed occurrence on `/mnt/storage`. A local SQLite catalogue stores full paths, names, entry types, extensions, sizes, content modification times, metadata change times, available creation times, and SHA-256 hashes for regular files. Nothing on the drive is moved, renamed, or deleted. Duplicate results are for inspection only.

## Use

Requires Linux, Node 24 or 26, `findmnt`, `flock`, `nice`, `ionice`, and `xdg-open`. There are no npm runtime dependencies and no build step. From this directory:

```bash
npm install --workspaces=false
npm run index
npm start
```

Open [Storage search](http://127.0.0.1:8765). Search by name or full path with fuzzy matching, substring matching, exact matching, or case-insensitive JavaScript regular expressions. Fuzzy matching accepts partial names, letters in order, and one typing error within a word (two for queries longer than seven characters). Short queries use partial names and letters in order only. Search is case-insensitive; SQLite exact and substring matching case-fold ASCII, while fuzzy matching and regular expressions also handle Unicode. Comma-separated extensions, entry type, date ranges, and duplicate content can narrow the results. Date ranges include both days in UTC. Creation times can be missing or reflect backup copying; filesystem metadata change time is separate from creation time.

Every path is a separate occurrence. Results have 100 entries per page with a total count and Previous/Next controls; there is no overall result cap. "Same content" clears the current filters and lists all indexed paths with that SHA-256 hash, including differently named copies. Hash matches also include hard links, and say nothing about backup quality or which copy should be kept. Hashes represent the last successfully indexed version, so verify files again before taking any later destructive action.

"Open folder" and "Open file" use the workstation file manager and default application. File URLs for both locations are also included in the search API response; the interface uses explicit open buttons because browsers commonly block direct file links. `openerEnvironment` in the configuration supplies the verified workstation display, X authority file, and session bus to the opener, including when the service was started by cron before login. Change those values for another graphical session. The page and search work before login; opening a result requires a logged-in desktop. Open actions require the configured drive and reject symlinks that resolve outside it. The service binds only to `127.0.0.1`, checks the Host header, and accepts open actions only from its own page. Anyone using this local workstation account can access the catalogue; it is not a multi-user or remotely hosted application.

## Configuration and data

[config.json](config.json) is the source of truth. `root` is the drive mount point; `mountUuid` identifies the expected filesystem. The supplied UUID was checked against the mounted drive. Use a different database for a different root. `database` resolves relative to the configuration file and must be outside the indexed root. The default database is `state/storage.sqlite` on the workstation, so searching remains possible while the drive is disconnected. Keep the whole `state/` directory private; paths and hashes can reveal sensitive filenames. It is ignored by Git, and its parent directory is created with mode 0700.

`exclude` contains literal relative paths and their descendants. The default excludes `lost+found`. Directories named `scratch` are always skipped in line with repository policy. Symlinks and other special entries are recorded but not followed or hashed. Nested filesystems are skipped. For a test directory rather than a mounted drive, `mountUuid: null` disables UUID validation; do not use this for the real external drive.

`hashBudgetMinutes` limits each update's hashing phase, checked between files. The default is 180 minutes; a single very large file can extend that budget. The name scan runs to completion before hashing begins, so filenames become searchable independently of hash completion. Reading the entire used capacity to calculate initial hashes can take a long time. Status shows coverage and bytes still pending; it does not claim an estimated finish time.

```bash
node src/cli.ts --status
node src/cli.ts --index --metadata-only
node src/cli.ts --index --config config.local.json
node src/cli.ts --index --rehash
node src/cli.ts --help
```

`--rehash` invalidates cached hashes as files are visited and is intended for a deliberate full verification pass. Normal updates reuse hashes only when path, entry type, device, inode, size, modification time, and metadata change time match. Each hash is streamed, with file identity and nanosecond timestamps checked before and after reading. Files that change during hashing have no accepted hash and are retried on the next update. Completed hashes are saved immediately. Inaccessible files and directories are reported, and any traversal error prevents deletion of old catalogue rows. Missing or mismatched mounts fail before scanning; old results remain available. An interrupted run also retains old rows, and restarts traversal on its next invocation. The CLI uses a kernel-held lock to prevent overlapping updates.

An incomplete or failed scan can leave stale paths alongside newer rows. The status section shows the last completed name scan, phase, pending hashes, and entry errors. File and folder counts include the indexed root itself and retained entries. Query filters read SQLite, never walk the drive. Broad fuzzy and regular-expression queries still scan database rows; use exact matching or narrower filters for large catalogues. Search runs in an isolated worker with an eight-second timeout, so an expensive expression cannot block the local service indefinitely.

## Scheduled operation

[cron.yaml](cron.yaml) is a separate Dotbot profile that reuses the repository's existing cron plugin. It installs updates every six hours, a startup update, and the local search server at startup. Apply it from the dotfiles root:

```bash
dotbot --base-directory "$PWD" --config-file tools/storage/cron.yaml
```

Reapplying this profile replaces only its three managed entries and preserves other cron jobs. The profile uses `~/.local/bin/node-cron`. The runner refreshes this link from installed NVM LTS releases before starting each job, including at boot, without network access or installation. See [Node runtime maintenance](../../docs/node-runtime.md) for explicit LTS updates and manual inspection. The profile is deliberately separate from the main dotfiles installation and package files.

[run.sh](run.sh) creates logs at `~/.logs/storage/YYYYMMDD-HHMMSS.log`, applies low CPU and disk I/O priority, and uses the repository logging library. Use the same runner for logged manual execution:

```bash
./run.sh --node "$(command -v node)" --index --verbose
./run.sh --node "$(command -v node)" --serve
```

`--quiet` disables verbose diagnostics, then `--verbose` enables them, then `DNB_VERBOSE=1` applies. Errors remain visible. Direct CLI runs print to the terminal; the runner captures output in the log. Stop a foreground command with Ctrl+C. Startup server jobs stay in the foreground under cron. To stop scheduled operation, set `state: absent` on the three entries in `cron.yaml`, and reapply the profile. This removes future launches; stop any already running process separately.

## Development and verification

Package and lock files are local to this tool. Use `npm install --workspaces=false` here to avoid changing the parent workspace lock. Run `npm run check` for strict TypeScript checking and temporary-directory integration tests. Tests cover duplicate occurrences and hashes, incremental updates, typing errors, regular expressions, filters, removals, symlink handling, exclusions, interrupted scans, offline search, and local HTTP protections. Run the repository's `npm run check` from its root as well.
