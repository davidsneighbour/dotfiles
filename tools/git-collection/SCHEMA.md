# Collection semantics and schema

The SQLite database is a rebuildable index of local Git history. Git repositories remain the source of truth. No collection command fetches, changes refs, or writes into a repository.

## Repository and commit identity

Each canonical local path has a persistent UUID within the database. Independent clones and worktrees are separate catalogue repositories, even when their remotes match. Moving a clone creates a new repository record. Rebuilding creates new UUIDs; portable reconciliation across database rebuilds is not implemented.

Commit identity is `(repository_id, full_hash)`. Both SHA-1 and SHA-256 are supported. Collection includes commit objects reachable from all local refs and detached HEAD. Tags pointing to trees or blobs do not contribute history. Reflog-only and unreachable objects are not initially imported. Git replacement objects are disabled. Lazy fetching and all Git transport protocols are disabled for collector and enrichment subprocesses, so missing objects in a partial clone do not trigger a fetch. These controls follow the [Git environment reference](https://git-scm.com/docs/git#Documentation/git.txt-GITNOLAZYFETCH). Counts refer to repository/commit pairs, so the same commit in two clones contributes twice.

The collector snapshots the set of commit tips before extraction and checks it again before committing. Ref changes during a scan cause rollback and a rerun instruction. This is a local observation, not a guarantee about unfetched upstream refs or objects. Shallow clones contribute only their available history and are always fully scanned so that changed shallow boundaries cannot be missed. Git graft files and concurrent repository maintenance are outside the supported collection contract; do not run Git garbage collection during a scan.

## Dates and messages

Author and committer dates use Git's ISO 8601 representation, including their original offsets. Collection timestamps use UTC. Activity views, search date filters, and reports group committer dates in Asia/Bangkok, using a fixed UTC+7 offset. Sort ISO dates from different offsets through `datetime()` or `unixepoch()`, not lexical ordering.

Git emits UTF-8 metadata, parsed as fixed NUL-delimited fields. Multiline bodies, Unicode, and record separator characters are supported. Each field is limited to 64 MiB. Embedded NUL bytes are outside the supported commit-message contract. Invalid framing or incomplete records cause a failed scan; raw binary commit messages are not supported. Subject/body fields reflect Git's `%s` and `%b` semantics; this is not a byte-for-byte archive of raw commit objects.

## Reachability and incremental collection

Each commit has `reachable`, `unreachable`, or `unknown` reachability. A complete scan of a non-shallow repository can classify retained commits absent from its current reachable set as unreachable. A shallow or failed scan and a missing discovered repository leave absent or retained history uncertain. Failed and missing repositories never cause deletion of commit metadata.

Successful scans store commit tip hashes as the checkpoint. Unchanged complete, non-shallow histories skip extraction. Changed histories exclude ancestry covered by available previous tips while extracting new metadata, then walk the full current reachable set separately. Missing checkpoint objects, failed scans, shallow boundaries, and `--full` cause full extraction. An empty repository is inexpensive to rescan. No date-only checkpoint is used.

Repository metadata, commits, reachability, and checkpoints are committed together. A durable `collection_runs` row is created before that transaction. Interrupted transactions roll back on recovery, and their running entries remain as evidence. Failed scans record their error and mark previous reachability uncertain in a separate transaction. Rerunning is safe. Existing commit metadata and first collected timestamps are preserved on conflict.

## Schema versions

Migrations use `PRAGMA user_version`. `init`, scans, reindexing, and enrichment upgrade supported older schemas. Read-only commands require the current version; unknown future versions fail. The current version is 3.

Version 1 defines `repositories`, `commits`, and `collection_runs`. Repository records contain UUID, canonical path, display name, object format, remote names and fetch URLs, shallow state, first/last seen timestamps, last successful scan, and scan state. Commit records contain author and committer names, emails, and dates, subject, body, parent count, and first collected timestamp. Their compound primary key enforces idempotence. Indexes cover hashes, author email, and both date fields; the primary key supports repository queries.

Version 2 adds repository ref checkpoints, per-commit reachability, per-repository run modes/durations, and `scan_runs` for overall execution summaries. It also adds contentless FTS5 indexing over subject, body, author name/email, and repository name. Triggers synchronise insertions, deletions, metadata changes, and repository renames. `reindex` reconstructs search data. Activity views are `v_commits`, `v_recent_commits`, `v_daily_activity`, `v_monthly_activity`, `v_repository_activity`, `v_repository_daily_activity`, and `v_author_activity`. They include retained history; SQL consumers can filter reachability explicitly.

Version 3 adds `commit_enrichment` and `commit_files`. Both reference the compound commit key and cascade on explicit commit deletion. Enrichment stores changed file counts, line totals, binary counts, completion state, errors, and timestamps. File records store path, status, and nullable insertion/deletion counts. Collection never depends on successful enrichment. GitHub data, tag and branch containment, and conventional commit fields remain optional future extensions.

Verification checks SQLite integrity, foreign keys, and FTS row counts. It does not check upstream completeness, every token's correspondence with current text, or the availability of retained Git objects. The tables do not enforce valid Git date formats beyond storing Git's emitted values; malformed commit dates can prevent report generation.

## Locations and access

The default database path is `~/.local/share/git-collection/catalogue.sqlite`, overridden by `--database`. New database files and snapshots use mode `0600`; newly created parent directories use `0700`. Existing directory permissions are not changed. Database content still includes author emails, messages, and local paths, so treat it as private local data. Credential userinfo is redacted, and query/fragment components are stripped from collected URL remotes; migrated old records are not retroactively redacted.

Discovery JSON defaults to `~/.config/git-collection/config.json`. It requires non-empty roots, accepts literal excluded subtrees, and bounds recursion with `maxDepth` from zero to 100, default four. Relative paths resolve against the config directory. Nested repositories, worktrees, bare repositories, and inactive repositories are eligible unless excluded. Symlink traversal, `.git` contents, and `node_modules` are excluded. Missing or unreadable roots are reported, not treated as a successful empty scope.

Backup and rebuild require explicit new destination files. SQLite's backup API creates consistent snapshots, which are verified before being published without replacing an existing file. A rebuild publishes only a fully scanned and verified replacement. Snapshot restoration preserves retained metadata; rebuilding from refs cannot restore unreachable or pruned history.

The daily runner writes UTC-named logs under `~/.logs/git-collection/`. Reports use an explicit owned output directory and a manifest for stale-file removal. The implementation has not installed discovery configuration, a daily schedule, or Obsidian integration outside this folder.
