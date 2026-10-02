# Git commit reports

Import selected Git commits into an Obsidian vault. The implementation lives in dotfiles; Markdown items and repository records live under `23 Eventlog/Github/` in the vault. The tool supports explicit imports, complete sync, legacy migration, Bases, daily scheduling, and uptime catch-up. See [SCHEMA.md](SCHEMA.md) for the data contract.

## Use the importer

Install dependencies with `npm install` from the dotfiles repository root. The vault directory must already exist. Start with a dry run:

```bash
npm run import --workspace @davidsneighbour/git-commit-reports -- --repo /path/to/repository --vault /path/to/vault --recent 20 --dry-run --verbose
npm run import --workspace @davidsneighbour/git-commit-reports -- --repo /path/to/repository --vault /path/to/vault --from 2026-10-01 --to 2026-10-02
npm run import --workspace @davidsneighbour/git-commit-reports -- --repo /path/to/repository --vault /path/to/vault --commit FULL_HASH
```

Choose exactly one selection: `--commit`, `--recent`, or `--from` together with `--to`. Dates are inclusive calendar dates in Asia/Bangkok, filtered against numeric committer timestamps after traversing the complete selected history. This finds backdated ancestors. `--recent` uses Git topological traversal, includes merges, and limits the returned count. `--ref` selects the traversal tip and defaults to HEAD; it cannot accompany `--commit`. Revisions must resolve unambiguously to commit objects. Annotated tags need explicit peeling such as `--ref refs/tags/release^{commit}`.

`--help` lists flags. `--quiet` suppresses successful output; errors still print and return non-zero. `--verbose` adds selected counts and the repository ID. `--dry-run` creates no files, directories, locks, or registrations. Its counts are a snapshot and a provisional ID is not reserved. Changed-note counts include the repository note but exclude operational cache files.

## Repository identity

New repositories receive a persisted `local-UUID` identity, including repositories hosted on GitHub. Canonical origin URLs remove credentials, query strings, fragments, and `.git` suffixes. GitHub path case is normalised. Matching hosted origins reuse an existing repository record, and worktrees share the common Git directory registration. Local filesystem origins are treated as clone locations; separate offline clones need an explicit shared ID.

Supply `--repository-id local-UUID` to reuse a known repository note after moving a clone or rebuilding its cache, or to confirm that a changed origin represents a rename. A rename retains its ID and records the former slug. Register a fork separately: its origin must be distinct, and it must use a separate clone registration. Changing a cached clone to another identity is refused. Multiple records with the same remote require explicit identity selection.

Existing `github-<numeric ID>` records can be reused, but this importer does not verify or register new GitHub IDs through the API. API-assisted registration remains deferred until rename, transfer, and recreation behaviour is verified. No network access is required for import, and missing partial-clone objects cause a failure rather than a lazy fetch.

The recoverable `.obsidian/git-commit-reports/repositories.json` cache maps common Git directories to IDs. Repository notes are the portable identity source. If the cache is lost, hosted origins resolve from those notes; pass the existing repository ID for repositories without a hosted origin. Do not edit IDs to represent repository names.

## Storage and recovery

Commit items use the full SHA-1 or SHA-256 hash and the committer date in Asia/Bangkok. Git replace objects are disabled. Raw commit messages are decoded strictly using the declared encoding, or UTF-8 when none is declared. Unsupported encodings, invalid byte sequences, and NUL characters fail explicitly. Message paragraphs, whitespace, and final-newline presence are preserved. Raw identity headers currently require UTF-8. The [Git object documentation](https://git-scm.com/docs/git-cat-file) describes the extraction operation, and the [YAML library documentation](https://eemeli.org/yaml/) describes the document parser used for frontmatter.

User labels, tags, custom properties, YAML comments, and repository-note bodies survive updates. Commit bodies must match both the raw message and their stored `body_sha256`; manual changes or conflicting immutable metadata cause an error and preserve the conflicting file. Resolve a body edit by moving the annotation to a custom property or another note and restoring the exact Git message. Reimport does not rewrite unchanged notes or update their timestamps. Generated records include `disabled rules: [all]`, the Obsidian Linter per-note opt-out, so formatting on save or file change cannot rewrite exact Git messages. Keep this machine-owned protection. If a formatter has already altered a body, preserve a private backup and restore the exact message from Git; do not change the digest to accept a reformatted message. Move annotations to user properties or separate notes instead of editing commit bodies.

Selected objects receive unknown membership status until a complete sync establishes reachability in monitored refs. Partial imports never mark other objects unreachable, and they retain existing verified membership observations.

Writers use a vault-wide `.git-commit-reports.lock` directory. Concurrent writers fail with an actionable message. After a crash, verify that no importer is running before removing that directory. Writes use same-directory temporary files, file sync, atomic rename, and directory sync. Imports publish registration and content together through the recovery journal described below. Migration uses separate journalled publications for report evidence and Git enrichment; rerunning resumes from the last completed publication. If a process is killed, orphan `.tmp` files can remain; they are ignored during indexing. Inspect and remove only those temporary files after stopping writers.

The importer rebuilds its commit index from notes and rejects duplicate identities, malformed notes, conflicting paths, and symlinks. Its lock coordinates these importers; it does not lock Obsidian or other editors. Avoid editing archive notes during an import. Dry runs do not take the writer lock and may observe an import in progress.

## Configure complete sync

Create `.obsidian/git-commit-reports/config.json` inside the vault. Use the ID printed by an explicit import with `--verbose`, or assign a local UUID once and persist it in the configuration. A new `github-ID` still requires a pre-existing verified repository note.

```json
{
  "schema_version": 1,
  "repositories": [
    {
      "id": "local-11111111-1111-4111-8111-111111111111",
      "paths": ["/absolute/path/to/clone"],
      "canonical_remote": "https://github.com/owner/repository",
      "fetch": "never",
      "refs": ["refs/heads/", "refs/remotes/origin/"]
    }
  ]
}
```

Set `canonical_remote` to the credential-free, normalised origin URL, or `null` for repositories without a hosted origin. Store credentials in the existing Git credential source, never in this configuration. Paths are absolute. List alternate clone locations in preference order; sync uses the first existing directory and records that clone in its observation. A present but invalid clone fails rather than silently switching evidence. Each repository ID occurs once. Clones and worktrees belong in that ID's `paths` list, rather than separate entries.

Run from the dotfiles repository root:

```bash
npm run sync --workspace @davidsneighbour/git-commit-reports -- --vault /path/to/vault --dry-run --verbose
npm run sync --workspace @davidsneighbour/git-commit-reports -- --vault /path/to/vault
```

The `refs` default is local branches and origin remote-tracking branches. Full names select one ref; values ending in `/` select a namespace. Only branch, origin, and tag namespaces are accepted. All local tags provide retention evidence, including annotated tags; tags pointing to non-commit objects provide no commit history. Stash, replace refs, unrelated remote namespaces, and detached HEAD are excluded. An object retained only by an excluded ref becomes unreachable under this scope. An empty monitored set is a valid complete observation.

Set `fetch` to `origin` only when updates from origin are required. Fetch uses an atomic, explicit `+refs/heads/*:refs/remotes/origin/*` refspec, an empty additional refmap, and branch-only pruning. It disables tag fetching, tag pruning, submodule recursion, FETCH_HEAD writes, and automatic maintenance. It never pulls, resets, merges, or checks out a worktree. Local branches and tags remain retention evidence even if an upstream branch is deleted. Local tag deletion affects the next scan; remote tag deletion is not established by this fetch policy. See the [Git fetch documentation](https://git-scm.com/docs/git-fetch) for refspec and pruning behaviour.

With `fetch: never`, status reflects the selected clone's local branches, cached origin refs, and local tags. It does not establish the current state of GitHub. Dry-run always skips fetch and logging, even when origin fetch is configured. Git operations have a 30-second timeout. The default SSH command disables interactive prompts; an existing `GIT_SSH_COMMAND` is retained.

Sync captures ref tips, imports the complete reachable history regardless of timestamps, prepares membership changes, and checks the tips again. It retries once if monitored refs move, then reports an incomplete scan if they continue to move. Shallow history, grafts, missing commit objects, failed fetches, conflicting bodies, and unavailable clones never establish absence. A failed repository retains its last verified memberships, other repositories continue, and the command returns non-zero for any repository failure.

## Observation state and sync recovery

`.obsidian/git-commit-reports/observations.json` records each repository's last attempt, completion flag, safe failure message, and last successful snapshot. Successful snapshots contain their observation time, clone location, fetch policy, monitored scope, ref tips, and selected count. Success is persisted after content writes. Routine checks update this state, while unchanged commit and repository notes retain their timestamps. A last-known reachable status may be stale; use the repository's last-success time and completion flag when interpreting it. Removing a repository from configuration retains its notes and its historical observation, rather than declaring its commits unreachable.

Sync uses the same vault-wide lock as imports. Before publication it records recoverable before/after contents in `.obsidian/git-commit-reports/pending.json`. A caught write failure rolls back the publication. After interruption, the next normal sync or migration rolls back the journal before scanning again. Explicit import, view installation, and dry-run refuse a pending journal. Publication and recovery reject destinations in legacy report folders. If recovery finds an external edit, it preserves that edit and the journal, and stops with an actionable error. Preserve both versions, resolve the conflict, and retry; do not discard the journal to hide an incomplete publication. Journal files contain note contents, so keep them within the vault's existing private operational storage.

Commit identities and memberships remain recoverable from the archive notes. If operational observations are lost, the next complete successful scan rebuilds them. If the identity cache is lost, the configured stable IDs reconnect clone locations with repository notes. A failed scan after state loss still preserves the note's existing memberships.

The `sync.sh` wrapper uses the existing `dnb_log_init` and `dnb_log` API and writes `YYYYMMDD-HHMMSS.log` files under `~/.logs/daily-reports/`. Logs contain repository IDs, counts, and actionable errors, without commit bodies or credentials. `DNB_VERBOSE=1` or `--verbose` enables per-repository console diagnostics. `--quiet` overrides both and suppresses successful console output; failures still print, and counts remain in the log. Help, read-only inventory, and dry-run create no logs. Archive writes share this wrapper and logging contract. The wrapper is the supported command entry point.

Unreachable means absent from a successful scan's monitored history. It does not mean globally deleted or confirmed as replaced. User-owned `superseded_by` links survive reconciliation. Daily polling cannot capture commits that appear and are rewritten between runs; missed runs do recover history that remains reachable.

## Migrate legacy reports and install views

Inventory and backfill use full hashes from legacy GitHub commit links. Run an inventory, review a dry run, apply the migration, and install the views:

```bash
npm run archive --workspace @davidsneighbour/git-commit-reports -- --vault /path/to/vault --action inventory
npm run archive --workspace @davidsneighbour/git-commit-reports -- --vault /path/to/vault --action migrate --clone-root /path/to/clones --dry-run
npm run archive --workspace @davidsneighbour/git-commit-reports -- --vault /path/to/vault --action migrate --clone-root /path/to/clones
npm run archive --workspace @davidsneighbour/git-commit-reports -- --vault /path/to/vault --action views
```

A clone root contains `owner/repository` directories. Repeat `--clone-root` for additional roots; configured sync clones are also considered. Canonical origins must match reported repository URLs. Migration reads locally available objects without fetching. The inventory reports report count, hash-link occurrences, distinct hashes, repository memberships, duplicate occurrences within a membership, and conflicting subjects. Migration's `recovered` and `reportOnly` counts are memberships, so shared history can appear in both counts. `changed` counts Markdown write operations across evidence and enrichment publications, rather than unique objects.

Original reports are never write destinations. Each item retains `legacy_reports` links and `legacy_evidence` containing the report path, line, date, subject, full hash, and URL. Unavailable objects retain report-only evidence with unknown membership status and `metadata_complete: false`. Their dates are provisional evidenced report dates; author identity, parents, precise timestamps, and full messages remain absent. Headings are never treated as author identities. Later import or migration enriches these records from actual Git objects. If the committer date changes the path, a redirect at the old path preserves existing links. Duplicate canonical hashes, conflicting bodies, and conflicting immutable metadata stop the operation and preserve the affected content.

In a Git-backed vault, generated records and operational state must be untracked and ignored before migration or view installation. Add narrow exclusions to that vault's local `.git/info/exclude`, following its privacy instructions:

```gitignore
/23 Eventlog/Github/items/
/23 Eventlog/Github/repositories/
/23 Eventlog/Github/observations/
/.obsidian/git-commit-reports/
/.git-commit-reports.lock/
```

The tool checks private note and state destinations; it does not edit ignore rules or stage files. Base definitions contain no commit bodies and can follow the vault's existing configuration tracking policy. The private migration ID map retains assigned repository IDs between interrupted runs. Do not discard it while unresolved report-only records depend on those identities.

`Commits.base` supplies All, Current, Unreachable, Uncertain, and Merges views, with linked subjects, dates, repository links, classifications, labels, and status. Uncertain includes unknown status or incomplete metadata. `Repositories.base` exposes linked repository titles, labels, retirement, last verified scan time, and the last attempt's completion flag. These freshness values come from rebuildable `observations/<ID>.md` presentation notes, generated from private operational state. They remain separate from canonical repository and commit timestamps. Migration alone does not establish monitored-ref reachability, so migrated memberships remain unknown until complete sync.

The views command refreshes observation presentation and installs the standard templates. Sync also refreshes presentation after attempts. Differing existing Base definitions are preserved and require a manual merge. Reopen a Base if Obsidian has not refreshed its derived values. `--action views --dry-run` reports pending changes without writing.

## Validate

Run from the dotfiles repository root:

```bash
npm run test --workspace @davidsneighbour/git-commit-reports
npm run typecheck --workspace @davidsneighbour/git-commit-reports
```

Tests create isolated repositories and vaults under the system temporary directory. They cover messages, merges, root commits, SHA-256, forks, clones, worktrees, unchanged imports, body and metadata conflicts, YAML preservation, date selection, ambiguous revisions, locking, symlinks, recovery, rewritten history, force-pushes, deleted refs, incomplete scans, concurrent ref movement, partial failure, legacy provenance, report-only enrichment, redirects, migration idempotence, private tracking safeguards, and view definitions. The repository check includes these tests, workspace typechecking, and scoped cron-removal tests.

## Scheduled operation and rollback

The authoritative `dotbot.yaml` alongside this tool defines an 08:00 daily job and an hourly catch-up job at minute 15. Both invoke `cron.sh` with explicit Node and vault paths and `--if-due`. The wrapper supplies a minimal executable PATH and does not load shell startup files. Update its pinned Node path when removing or replacing that installed runtime. The locutus profile includes this definition; it removes only the two matching legacy reporting jobs through `state: absent`, preserving other cron entries.

```bash
bash tools/git-commit-reports/cron.sh --node /absolute/path/to/node --vault /path/to/vault --if-due --dry-run
bash tools/git-commit-reports/cron.sh --node /absolute/path/to/node --vault /path/to/vault --if-due
```

The daily cycle starts at 08:00 Asia/Bangkok. Before 08:00, a missed previous cycle remains due. After a fully successful scheduled sync, private `schedule.json` records the completed cycle. Hourly checks skip it. A failed or partly failed run does not advance completion and retries during the next catch-up. This handles devices that were off at the daily time without relying on a reboot delay. Configured repositories are explicit; adding a local directory alone does not expand the scope. Fetch remains controlled per repository.

A separate private `schedule.lock` prevents duplicate scheduler processes; normal archive writers retain the vault lock. After a crash, stop all writers before removing a stale lock. Clear `schedule.json` to request another scheduled run after checking failure state; direct sync also runs regardless of that marker. Avoid editing archive files while any writer is active. Logs remain under `~/.logs/daily-reports/` with dated names, including skipped cycles and failure messages.

Before deployment, save the installed crontab privately. Apply only this tool's Dotbot definition, rather than unrelated host directives. Verify that the two legacy jobs are absent and both new entries exist. Keep legacy sources and reports for rollback. To roll back, stop archive writers, restore the saved crontab, and remove this tool's include before rerunning a host profile. This stops new scheduled writes without deleting the canonical archive, observations, or old reports. Restore any retired vault-local job definition from the private deployment backup only if reverting the include chain as well.
