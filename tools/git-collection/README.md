# Git commit catalogue

A local, rebuildable SQLite index of Git commit metadata. Git repositories remain the source of truth. The collector does not fetch, change refs, or edit repository files. Requires Node 24 or newer and Git; the core commands need no additional runtime dependencies.

See [PLAN.md](PLAN.md) for current progress, [SCHEMA.md](SCHEMA.md) for collection rules, [QUERIES.md](QUERIES.md) for SQL examples, and [INTERFACES.md](INTERFACES.md) for Datasette and DBeaver.

## Current local scope

The live catalogue is `tools/git-collection/state/catalogue.sqlite`. After review of the dotfiles pilot, the user approved wider collection under `~/github.com/davidsneighbour/`. The ignored `config.local.json` lists 360 verified real repository roots: top-level repositories discovered at depth one, plus the existing `dotfiles/protected` target. Collection uses these explicit roots at depth zero, so nested repositories and symlink traversal remain excluded. Newly created repositories need a configuration update.

The expanded backfill collected 294,357 additional commits without failures, bringing the catalogue to 296,362 commits. File enrichment remains optional and incomplete for the wider history; scheduled updates process up to 500 pending commits per run. Reports cover all collected metadata regardless of enrichment progress. See [PLAN.md](PLAN.md) for verification and the snapshot taken before widening the scope. To update this scope manually, run:

```bash
node tools/git-collection/src/cli.ts scan --all --config tools/git-collection/config.local.json --database tools/git-collection/state/catalogue.sqlite
```

## Start with one repository

Run these commands from the dotfiles repository root. Replace `/path/to/repository` with its actual root, bare repository, or worktree path:

```bash
node tools/git-collection/src/cli.ts init --database tools/git-collection/state/catalogue.sqlite
node tools/git-collection/src/cli.ts scan --database tools/git-collection/state/catalogue.sqlite --repository /path/to/repository
node tools/git-collection/src/cli.ts status --database tools/git-collection/state/catalogue.sqlite
node tools/git-collection/src/cli.ts verify --database tools/git-collection/state/catalogue.sqlite
```

`state/` is ignored by Git. Omit `--database` to use `~/.local/share/git-collection/catalogue.sqlite`. Use `--help` for all flags and `--verbose` for the database path and per-repository full-scan details. Missing required flags and failures produce an actionable error and a non-zero exit code. Status, search, reports, backup, and verification open an existing database read-only. `init` upgrades old supported schemas without deleting their commits.

## Discover and collect repositories

Discovery requires explicit roots. There are no assumed roots. Inspect the discovered paths before the first backfill:

```bash
node tools/git-collection/src/cli.ts discover --root /path/to/repositories --max-depth 4
node tools/git-collection/src/cli.ts scan --all --root /path/to/repositories --max-depth 4 --database tools/git-collection/state/catalogue.sqlite --verbose
```

Repeat `--root` for multiple roots and `--exclude` for excluded subtrees. Exclusions are literal paths, not globs. A root has depth zero; its direct children have depth one. Discovery includes nested repositories, worktrees, bare repositories, and inactive repositories. It skips `.git` contents, `node_modules`, and symlink entries. An explicit root that contains a symlink is rejected; supply its real path instead. Overlapping roots are deduplicated.

For repeatable scans, copy [config.example.json](config.example.json) to `tools/git-collection/config.local.json`, replace its placeholder paths, and use:

```bash
node tools/git-collection/src/cli.ts discover --config tools/git-collection/config.local.json
node tools/git-collection/src/cli.ts scan --all --config tools/git-collection/config.local.json --database tools/git-collection/state/catalogue.sqlite
```

Only `roots`, `exclude`, and `maxDepth` are valid configuration keys. Relative paths are resolved against the configuration file's directory. The default configuration location is `~/.config/git-collection/config.json`. Use either `--config` or `--root`; command-line roots do not merge with a configuration file.

Unchanged complete repositories skip history extraction. Changed repositories collect commits beyond the previous successful ref tips, then recompute reachability. Missing old tip objects, previously failed scans, shallow boundaries, and `--full` trigger full extraction. Scans retain previously collected commits and their first collected timestamps. Failure rolls back the import, records a failed run, and marks retained history for that repository as uncertain. Repositories missing from the current discovery scope also retain their history with uncertain reachability. Excluded and out-of-scope repositories are left alone.

The summary records discovered/scanned/changed repository counts, added commits, failures, duration, and database size. `--verbose` also shows each repository's mode and duration. Failed repositories do not stop other repositories from being scanned, but the overall command exits non-zero. A run left in `running` state records process interruption; rerun the same scan. A SQLite read-only connection may need a writable parent directory to recover a hot journal after abrupt termination; running a scan first performs that recovery.

## Search

```bash
node tools/git-collection/src/cli.ts search --database tools/git-collection/state/catalogue.sqlite --query '"reduced motion"'
node tools/git-collection/src/cli.ts search --database tools/git-collection/state/catalogue.sqlite --query 'subject:fix' --repository dotfiles --since 2026-10-01 --until 2026-10-31 --limit 100
node tools/git-collection/src/cli.ts reindex --database tools/git-collection/state/catalogue.sqlite
```

`--query` accepts SQLite FTS5 expressions, including phrases, prefixes, and field filters: `subject`, `body`, `author`, and `repository`. `--repository` matches an exact name, UUID, or canonical path; names can match multiple clones. `--author` matches an exact author email. Date filters are inclusive committer activity dates in Asia/Bangkok. Results include retained unreachable and uncertain commits. `reindex` regenerates search data from the commit tables. Verification checks SQLite integrity, foreign keys, and search row counts; it does not prove that local clones contain complete upstream history.

## Daily operation

The daily runner uses the same collector, records summaries, and writes UTC-named logs under `~/.logs/git-collection/YYYYMMDD-HHMMSS.log`. Successful execution is quiet unless `--verbose` is supplied. Failure prints the log path and returns a non-zero exit code. Rerun the same command after fixing the cause reported in the log:

```bash
node tools/git-collection/src/daily.ts --config tools/git-collection/config.local.json --database tools/git-collection/state/catalogue.sqlite --verbose
```

For cron, use absolute paths to Node, the runner, the configuration, and the database. Get Node's current path with `node -p 'process.execPath'`; cron does not automatically load an interactive Node version manager. The installed jobs use `/usr/bin/flock -w 300` to serialise scheduled updates. A lock timeout exits unsuccessfully and is reported by cron. `--output` runs collection, resumable file enrichment, and report generation in order, stopping on the first failure and recording each stage in the same log. Without `--output`, the runner only collects metadata.

The locutus host profile in `configs/dotbot/config.host-locutus.yaml` defines two jobs: daily at 08:15 Asia/Bangkok and at startup. Both use the expanded 360-repository `config.local.json`, `state/catalogue.sqlite`, and local `reports/`. Stable Dotbot IDs allow repeat installation without duplicate jobs. Existing jobs are preserved. The command pins the verified Node 26.8.1 executable; if that version is removed, update its absolute path in the host profile and reapply Dotbot. Inspect installed jobs with `crontab -l`. Run the daily command above with `--output tools/git-collection/reports` to refresh the same review output manually. These jobs read local Git history; they do not fetch repositories or write into an Obsidian vault.

## Backup and recovery

Create a new, consistent snapshot using SQLite's backup API. Existing destination files are never overwritten:

```bash
node tools/git-collection/src/cli.ts backup --database tools/git-collection/state/catalogue.sqlite --destination tools/git-collection/state/backups/catalogue-20261004.sqlite
node tools/git-collection/src/cli.ts verify --database tools/git-collection/state/backups/catalogue-20261004.sqlite
```

Stop scheduled writers before restoring. Copy the verified snapshot to a new working path, verify it, query it, and use that path for subsequent scans. Keep the previous database until its replacement is checked. Transfer the completed snapshot with rsync if needed; do not copy a live database file as a backup.

Reconstruction writes to a new database and publishes it only when every discovered repository scan and verification succeeds:

```bash
node tools/git-collection/src/cli.ts rebuild --config tools/git-collection/config.local.json --destination tools/git-collection/state/rebuilt.sqlite
node tools/git-collection/src/cli.ts verify --database tools/git-collection/state/rebuilt.sqlite
node tools/git-collection/src/cli.ts status --database tools/git-collection/state/rebuilt.sqlite
```

A rebuild creates new repository UUIDs. It reconstructs currently reachable local history; previously indexed commits whose Git objects are no longer reachable cannot be reconstructed from refs alone. Snapshots preserve that retained metadata, along with enrichment and run history. An incomplete rebuild leaves the original database and requested destination unchanged.

## Optional enrichment

```bash
node tools/git-collection/src/cli.ts enrich --database tools/git-collection/state/catalogue.sqlite --statistics --limit 500
node tools/git-collection/src/cli.ts enrich --database tools/git-collection/state/catalogue.sqlite --files --repository dotfiles --limit 500
```

Repeat these commands until `enriched` and `failures` are both zero. Completed work is skipped. Failed work is retried, and failures are recorded separately from collection. `--files` includes statistics and stores individual paths and statuses. Root commits are compared with an empty tree; merges are compared with their first parent. Renames are represented as deletion and addition. Binary line counts are null and contribute zero to numeric line totals; binary file counts remain separate. Tabs, newlines, and Unicode in paths are supported; non-UTF-8 path bytes are decoded as UTF-8 and are not preserved byte-for-byte.

Pruned objects, missing clones, and unavailable shallow or partial-clone objects can prevent enrichment without changing collected metadata or search results. A batch with failures exits non-zero. Other optional enrichment, such as tags, branch containment, conventional commit fields, and GitHub metadata, is not implemented.

## Disposable reports

```bash
node tools/git-collection/src/cli.ts reports --database tools/git-collection/state/catalogue.sqlite --output tools/git-collection/reports
```

The output includes `daily/`, `weekly/`, `monthly/`, and `repositories/`, plus a generated-file manifest. Repository filenames use catalogue UUIDs to avoid collisions. Each summary includes counts and the 20 most recent commits for its group. Recent examples are gathered in one window query per report type, avoiding a full catalogue scan per report. Dates use Asia/Bangkok, and weekly reports use ISO weeks. Counts include separate clones and retained rewritten history.

Rerunning replaces recognised generated files and removes stale files listed in the previous manifest. Unrelated files remain; unrecognised content at a required report path causes a failure. Symlink destinations are rejected. Files are replaced atomically, but a whole report tree is not replaced as one transaction. Delete the output and rerun to recreate it. Reports can later be written to a dedicated Obsidian subfolder, but no vault is changed by this implementation.

## Validation

```bash
node --test tools/git-collection/tests/*.test.ts
./node_modules/.bin/tsc --project tools/git-collection/tsconfig.json
./node_modules/.bin/markdownlint-cli2 --config ./node_modules/@dnbhq/markdownlint-config/.markdownlint-cli2.jsonc 'tools/git-collection/*.md'
```

Tests use temporary repositories and databases. They cover 100,000 commits, SHA-256, merges, Unicode, detached HEAD, discovery, shallow and partial clones, rewritten and pruned history, interrupted writes, daily logging, FTS synchronisation, schema upgrades, snapshots, reconstruction, enrichment, and report regeneration. The root `npm run check` remains the full repository gate; folder tests are separate because no root configuration has been changed.
