# Git commit catalogue — implementation plan

**Goal:** Build a local, portable, searchable catalogue of commits from all relevant Git repositories, updated daily and capable of being rebuilt entirely from the repositories.

**Core stack:** SQLite → collector → SQL views/FTS → Datasette/DBeaver → optional derived reports.

## Current state

Updated: 4 October 2026. The folder-local implementation, initial live backfill, and live recovery checks are complete. Collection is ready for manual use and scheduled on locutus at startup and daily at 08:15 Asia/Bangkok. The user authorised committing all changes and cron integration; the two jobs are defined in the existing host Dotbot profile.

* [x] Milestone 1: Collection semantics, configuration rules, and versioned schema documented in [SCHEMA.md](SCHEMA.md).
* [x] Milestone 2: SQLite initialisation, migrations through version 3, status, and integrity verification.
* [x] Milestone 3: Streaming single-repository importer; 100,000-commit fixture, repeated imports, failed-write rollback, and real SIGKILL recovery pass.
* [x] Milestone 4: The user-selected `dotfiles*` scope is configured, discovered, and backfilled. All five repositories were collected without failures. Repeat scans and full reconstruction match the live catalogue.
* [ ] Milestone 5: Incremental ref checkpoints, detached HEAD, history rewriting, pruned checkpoints, shallow clones, failed scans, and disappearing repositories pass. The daily runner passes three consecutive fixture scans, logging, and failure checks. Two unchanged live repeat scans pass. Cron installation and a live run with an empty environment pass. Consecutive real daily executions remain an operational acceptance check.
* [x] Milestone 6: FTS5 search, repository/author/date filters, insert/update/delete synchronisation, and reindex pass.
* [x] Milestone 7: All seven SQL views are implemented. Bangkok date boundaries pass, and all 12 documented SQL queries execute successfully. See [QUERIES.md](QUERIES.md).
* [x] Milestone 8: Datasette 0.65.5 table browsing, FTS search, and named queries pass six local HTTP checks. Reproducible interface instructions and an optional HTTP check are in [INTERFACES.md](INTERFACES.md). DBeaver is documented as optional and remains untested on the desktop.
* [x] Milestone 9: Consistent snapshots, no-overwrite safeguards, snapshot restoration, queries against restored data, and reconstruction from Git pass. Failed rebuilds do not publish incomplete destinations.
* [x] Milestone 10: Resumable statistics and file enrichment pass for unusual paths, binary files, merges, empty commits, and failed batches. Partial clones do not fetch missing blobs. Tags, branch containment, conventional commit fields, and GitHub data remain optional future work.
* [ ] Milestone 11: Daily, ISO-weekly, monthly, and repository summaries pass deterministic regeneration, stale-file removal, and ownership checks. Live Obsidian output is pending because a vault destination is outside the folder-only scope.

Implemented commands and complete usage are in [README.md](README.md). Runtime databases, interface dependencies, and fixtures are ignored under `state/`; generated reports are ignored under `reports/`. A folder-local Markdown configuration excludes runtime dependencies and generated reports from source-documentation linting. The configured roots remain the five explicit dotfiles repositories. The installed schedules refresh metadata, file enrichment, and local reports under one lock; existing jobs remain unchanged.

### Verification

Verified on 4 October 2026 with Node 26.8.1 and Git 2.53.0: all 16 tests pass, strict TypeScript checking passes, scoped Biome checks pass, scoped secretlint passes, six Datasette HTTP checks pass, and all 12 documented SQL queries execute. Folder Markdown lint passes. The repository-wide `npm run check` passes its tests, config lint with existing warnings, and typechecks, then stops at 19 existing Markdown errors in 14 files outside this folder after correcting the staged Chrome prototype list style. The separate `npm run lint:shell` passes. Those unrelated files have not been changed by this task.

Measured in the latest synthetic 100,000-commit fixture: initial import 4,910 ms; unchanged scan 25 ms; phrase search 0.81 ms; database size 61,063,168 bytes. These are measurements of one local fixture run, not estimates for the live repository collection. Live scope measurements are recorded below.

### Live scope and results

The user selected `~/github.com/davidsneighbour/` and excluded everything except `dotfiles*` for now. `config.local.json` contains the verified real paths of its five current matching directory entries, with `maxDepth: 0` and no additional exclusions. All other projects and nested repositories are excluded by this explicit root list. New matching directories will not be added automatically. `dotfiles-protected` is a symlink, so its verified target is supplied directly; discovery does not traverse the link.

| Matching entry | Indexed commits |
| --- | ---: |
| dotfiles | 1,796 |
| dotfiles-ai | 49 |
| dotfiles-containers | 34 |
| dotfiles-containers-pi | 1 |
| dotfiles-protected (target: dotfiles/protected) | 123 |
| Total | 2,003 |

Verified on 4 October 2026: first backfill completed in 236 ms with zero failures. Two unchanged live scans added zero commits and took 114 ms and 105 ms. None of the selected clones is shallow. Snapshot restoration and a new reconstruction reproduced the same ordered commit metadata, including messages, dates, parent counts, and reachability; reconstruction imported 2,003 commits in 218 ms. Comparison SHA-256: `268ce8d704b2462b2c3b7f7e595808cada2b7f62996384a55692c11e0af57df7`.

The requested scope was rechecked and scanned again on 4 October 2026: five repositories, zero changed repositories, zero added commits, zero failures, and 120 ms duration. Database integrity verification passes.

File enrichment completed for all 2,003 commits without failures and stored 301,914 changed-file records. A repeat enrichment skipped all completed records. Reports produced 480 files, and repeat generation passed. Six Datasette HTTP checks pass against the live catalogue. Integrity verification passes, and an additional verified snapshot includes the completed enrichment.

Current database: `state/catalogue.sqlite` (101,158,912 bytes after enrichment). Live results and the latest snapshot path are recorded in `state/live-validation.json`. The snapshot/restore/rebuild comparison files are under `state/recovery/2026-10-04T04-07-01-582Z/`; the enriched snapshot is under `state/backups/`. Configuration, databases, snapshots, reports, and validation state remain private local, gitignored files inside this folder.

### Scheduled operation

Verified on 4 October 2026: the locutus Dotbot profile defines stable IDs `git-collection-daily` and `git-collection-startup`. The active cron service runs updates at 08:15 Asia/Bangkok and at reboot. All 15 existing crontab rows were preserved. Reapplying the two entries produced an identical crontab without duplicates. The command uses the absolute Node 26.8.1 path and a 300-second flock wait, then scans, enriches files, and regenerates local reports. A live execution with an empty environment discovered exactly five repositories, collected the implementation commit, completed enrichment without failures, and generated 481 reports. Logs use UTC filenames under `~/.logs/git-collection/`. Real day-to-day and reboot execution have not yet been observed.

### Next actions

1. Manual collection is ready: use the commands in [README.md](README.md) with `config.local.json` and `state/catalogue.sqlite`.
2. Review the local reports and catalogue before widening discovery. The cron jobs are installed and verified; observe consecutive daily executions in `~/.logs/git-collection/`. Keep the five explicit roots until the user authorises wider collection.
3. If Obsidian reports are wanted, the user supplies an owned vault subfolder and authorises that destination. The 480 current reports already exist inside this folder and can be regenerated safely.

### Milestone 1 — specification and data model

Before implementing collection, define what the catalogue actually represents.

* Define repository discovery rules.
  * Which root directories are searched?
  * Recursive discovery depth/behaviour.
  * Bare repositories?
  * Worktrees?
  * Archived/inactive repositories?
* Define commit identity as `(repository_id, full_hash)`.
* Define canonical metadata collected per repository and commit.
* Decide which Git dates we preserve: author and committer dates should both be stored.
* Define timezone handling.
* Decide whether file-level statistics belong in the initial schema or a later enrichment stage.
* Define database location, configuration location and backup location.
* Document the database as a **rebuildable index**, not the canonical Git history.

**Gate:** We have a documented schema and collection semantics before writing the importer.

---

<!-- markdownlint-disable-next-line dnb-title-case-style -->
### Milestone 2 — SQLite foundation

Create the database infrastructure independently of repository scanning.

Initial tables:

```text
repositories
commits
collection_runs
```

Add:

* primary keys;
* foreign keys;
* unique `(repository_id, hash)` constraint;
* indexes for repository, dates, hashes and authors;
* schema versioning/migrations;
* database initialization command;
* integrity-check command.

Provide commands conceptually equivalent to:

```text
git-catalog init
git-catalog status
git-catalog verify
```

The implementation should never require manually creating tables.

**Gate:** An empty database can be created, inspected, verified, deleted and recreated reliably.

---

### Milestone 3 — single-repository collector

Implement Git extraction against **one explicitly supplied repository** first.

Collect at minimum:

```text
full hash
repository
author name
author email
author date
committer name
committer email
committer date
subject
body
parent count
collected timestamp
```

Requirements:

* parameterized Git commands;
* no parsing of human-oriented Git output;
* safe handling of multiline commit messages and unusual characters;
* transactional database writes;
* idempotent imports;
* meaningful error reporting;
* interrupted imports can simply be rerun.

Test against repositories containing merges, empty bodies, Unicode, unusual author data and substantial histories.

**Gate:** Importing the same repository repeatedly produces exactly the same catalogue contents.

---

### Milestone 4 — repository discovery and full backfill

Add discovery of all repositories covered by configuration.

The collector now supports conceptually:

```text
git-catalog scan --repository ...
git-catalog scan --all
git-catalog rebuild
```

Record repository metadata including:

```text
path
name
remote URL(s)
first seen
last seen
last scan
scan state
```

Perform the first complete historical import.

This is also where we measure reality rather than optimize speculatively:

```text
repositories discovered
commits discovered
database size
initial import duration
per-repository duration
```

100k+ commits should now be perfectly normal.

**Gate:** The entire catalogue can be deleted and reconstructed from the configured Git repositories.

---

### Milestone 5 — incremental daily collection

Now optimize normal operation.

The collector determines what changed since the previous successful scan rather than processing complete histories unnecessarily.

Account for:

* new commits;
* multiple branches;
* newly discovered repositories;
* repositories that disappeared;
* force-pushes/history rewriting;
* detached HEAD;
* previously failed scans.

Record every execution in `collection_runs`.

A run should provide a useful summary such as:

```text
Repositories scanned: 143
Repositories changed: 8
Commits added: 37
Failures: 0
Duration: 4.8s
```

Only after this works reliably do we connect it to the existing daily cron infrastructure.

**Gate:** Several consecutive daily scans, including scans with no changes, behave predictably and remain idempotent.

---

### Milestone 6 — search and FTS5

Add SQLite FTS5 over appropriate textual fields.

Likely:

```text
subject
body
author
repository
```

Provide a straightforward search interface:

```text
git-catalog search --query "reduced motion"
```

with optional filters eventually supporting repository/date/author.

Verify that the FTS index stays synchronized with the canonical commit table and can be rebuilt.

**Gate:** Searching the complete catalogue is fast enough to be effectively interactive.

---

### Milestone 7 — SQL views and reporting model

Build useful views without changing canonical data.

Initial candidates:

```text
v_commits
v_recent_commits
v_daily_activity
v_monthly_activity
v_repository_activity
v_repository_daily_activity
v_author_activity
```

Views should provide the foundation for future reporting rather than embedding reporting logic into Bash.

Also document useful example SQL queries.

**Gate:** The questions we originally wanted Obsidian Bases to answer can instead be answered directly through SQL.

---

<!-- markdownlint-disable-next-line dnb-title-case-style -->
### Milestone 8 — Datasette and DBeaver

Add the human interfaces only after the database itself is mature.

Configure Datasette as a lightweight local browser for:

* tables;
* views;
* FTS search;
* filtering;
* saved/named queries where useful.

Document DBeaver Community as the development/exploration GUI rather than making it a system dependency.

No important functionality should require either interface.

**Gate:** The catalogue can comfortably be explored without using the CLI or writing SQL for routine questions.

---

### Milestone 9 — backup and disaster recovery

Create consistent SQLite snapshots rather than rsyncing a potentially active database.

Conceptually:

```text
live database
     ↓
SQLite backup / VACUUM INTO
     ↓
snapshot
     ↓
rsync
```

Implement and test:

```text
git-catalog backup
git-catalog verify
git-catalog rebuild
```

Actually perform a recovery test:

1. back up database;
2. move/delete working database;
3. restore snapshot;
4. run integrity checks;
5. query restored data.

Also test complete reconstruction from Git.

**Gate:** Both snapshot restoration and full reconstruction have been demonstrated rather than merely documented.

---

### Milestone 10 — enrichment

Only now consider expensive/nonessential information.

Possible additions:

```text
commit_files
file status
insertions
deletions
files changed
branches containing commit
tags
conventional-commit type
conventional-commit scope
GitHub repository metadata
```

I'd particularly separate **cheap commit metadata** from **expensive enrichment** so that adding statistics doesn't make ordinary daily collection cumbersome.

Historical enrichment should be independently resumable:

```text
git-catalog enrich --statistics
git-catalog enrich --files
```

**Gate:** Enrichment can fail or be disabled without affecting the core commit catalogue.

---

### Milestone 11 — derived reports / obsidian integration

Reintroduce Obsidian only at the very end.

Instead of one file per commit, generate useful human-oriented summaries from SQL:

```text
reports/
├── daily/
│   └── 2026-10-03.md
├── weekly/
│   └── 2026-W40.md
├── monthly/
│   └── 2026-10.md
└── repositories/
    └── <repository-uuid>.md
```

These files are disposable.

```text
Git repositories
       │
       ▼
   SQLite DB
       │
       ├──── Datasette
       ├──── DBeaver
       ├──── CLI/search
       │
       └──── report generator
                    │
                    ▼
                 Obsidian
```

Deleting every generated report and regenerating it must be safe.

**Gate:** Obsidian contains useful summaries without becoming part of the storage architecture.

---

## Implementation order

I'd lock the actual work sequence to:

```text
1  Specification + schema
          ↓
2  SQLite infrastructure
          ↓
3  One-repository importer
          ↓
4  Discovery + complete historical backfill
          ↓
5  Incremental updates + cron
          ↓
6  FTS search
          ↓
7  SQL views
          ↓
8  Datasette / DBeaver
          ↓
9  Backup + tested recovery
          ↓
10 Optional enrichment
          ↓
11 Optional Obsidian reports
```

The critical boundary is **Milestone 5**. At that point we already have the actual replacement for yesterday's system: a reproducible, indexed, incrementally maintained commit database. Everything after that makes the data nicer to query, inspect and consume rather than being necessary for its integrity.
