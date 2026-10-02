# Data contract

This is the version 1 target contract. The foundation, explicit importer, and complete sync are implemented. Legacy migration and vault views are implemented.

## Commit items

Identity is `(object_format, hash)`. Validate the full lowercase hexadecimal hash before constructing a path. Folder date is committer time converted to the immutable storage timezone. Query timezone changes must not move items.

Machine-owned properties: `type: git-commit`, `schema_version: 1`, `hash`, `object_format`, `title`, `date`, `date_basis`, `timezone`, `authored_at`, `committed_at`, `author_name`, `author_email`, `committer_name`, `committer_email`, `parents`, `parent_count`, `is_merge`, `repositories`, `repository_ids`, `commit_urls`, `reachable_in`, `unreachable_in`, `unknown_in`, `status`, `status_changed_at`, `created`, `updated`, `metadata_complete`, `source`, optional `commit_type`, `commit_scope`, `breaking_change`, `legacy_reports`, and `legacy_evidence`.

`repositories` contains vault wikilinks to stable repository notes. Membership status lists contain stable IDs. Lists are deduplicated and sorted except `parents`, whose Git order is significant. Aggregate status is reachable when any membership is reachable, unknown when none is reachable and any membership is unknown (or there are no observations), and unreachable otherwise.

The body is the full commit message. Preserve paragraphs; do not reflow it. Decode the message strictly using its declared encoding, or UTF-8 by default, and preserve final-newline presence. All generated Git records also have machine-owned `disabled rules: [all]` to prevent Obsidian Linter rewrites. The machine-owned `body_sha256` stores the SHA-256 digest of the exact decoded body to detect manual edits. Raw identity headers require UTF-8; unsupported messages fail explicitly. A conflict preserves the file and produces a non-zero result; repair must be explicit.

User-owned properties: `labels`, `superseded_by`, and unknown custom fields. Preserve them. `tags` retains user tags and adds the fixed `git-commit` tag. `created` is first item creation; `updated` changes only with meaningful content changes. Routine checks do not update either timestamp. Git classification is optional and never rejects non-conventional subjects.

For report-only migration records, immutable fields unavailable from the source remain absent, `metadata_complete` is false, and membership starts unknown. The typed complete commit model is not used to fabricate missing data. `date_basis` is `legacy-report-provisional`; complete Git metadata uses `committer`. `source` records `legacy-report` until enrichment. `legacy_evidence` retains objects with `report`, `line`, `repository_url`, `hash`, `date`, `title`, and `url`; `legacy_reports` contains wikilinks to originals. These survive enrichment.

A relocated provisional item becomes a `git-commit-redirect` at its former path, with `schema_version: 1` and `redirect_to` pointing at the canonical item. Redirects are excluded from canonical indexes and Bases; they preserve full-path links without creating a second commit identity.

## Repository records

Path: `23 Eventlog/Github/repositories/<ID>.md`. IDs are `github-<numeric ID>` or `local-<UUID>`, never hashes of names. Assigned IDs are persisted once and must not be regenerated on each import.

Properties: `type: git-repository`, `schema_version: 1`, `repository_id`, `title`, `host`, `slug`, `former_slugs`, optional `url`, `retired`, `created`, `updated`, and user `labels`. A rename retains its ID and adds the previous slug. A fork receives a separate ID. Unknown custom fields survive updates.

Clone paths, credentials, configured refs, fetch settings, checkpoints, failures, and routine scan timestamps belong under `.obsidian/git-commit-reports/`, not these content records. Repository notes are the portable identity source; operational indexes can be rebuilt.

## Observation rules

A successful complete observation of configured refs can establish unreachable status. A failed or incomplete observation never replaces a verified reachable/unreachable observation; operational state records the failure and stale evidence. Unknown is used when there has never been adequate evidence. The Repositories Base exposes observation freshness from a repository-level view so a last-known reachable item is not presented as freshly checked.

Unreachable records remain historical evidence. Missing local objects, HTTP failures, and disappeared directories do not prove global deletion. Confirmed replacement links are separate from machine-observed status. If a hash reappears in monitored history, its membership returns to reachable.

## Operational sync contract

Configuration lives at `.obsidian/git-commit-reports/config.json`, with `schema_version: 1` and a `repositories` list. Each entry has a stable `id`, absolute preferred clone `paths`, `canonical_remote` (hosted URL or null), `fetch` (never or origin), and optional `refs` (full names or namespace prefixes). Branches and origin refs are the default; all local tags provide retention evidence.

`observations.json` stores `schema_version: 1` and a repository-ID mapping. Each observation contains `last_attempt`, `complete`, optional `error`, and optional `last_success`. A successful snapshot stores `at`, `refs`, `selected`, `clone`, `fetch`, and `scope`. Failure preserves the previous successful snapshot and note memberships. Configuration removal retains historical state.

`pending.json` is a private recovery journal containing before/after contents for an interrupted publication. Recover under the vault lock before taking new observations. Rollback refuses conflicting external edits. Successful observation state is the final write in each repository publication.

## Derived vault presentation

`Commits.base` filters canonical items by type and supplies All, Current, Unreachable, Uncertain, and Merges views. `Repositories.base` reads last-success time and last-attempt completion through `23 Eventlog/Github/observations/<ID>.md`. These `git-observation-view` notes contain `repository`, `complete`, `last_attempt`, `last_success`, `fetch`, and `error`; they are rebuildable presentation of `observations.json`, not canonical observations. View installation and sync refresh them without changing canonical record timestamps.

`migration-repositories.json` maps canonical reported repository URLs to assigned IDs. Migration retains this private map across evidence and enrichment publications. Legacy reports are excluded from publication and recovery destinations.

## Schedule state

`schedule.json` contains `schema_version: 1`, `day` (the completed 08:00 Asia/Bangkok cycle), and `completed_at`. Only a fully successful scheduled sync advances it. It is an optional private optimisation: deleting it makes the next scheduled check run again without changing identity or membership rules. `schedule.lock` coordinates scheduler processes separately from the content writer lock. Scheduler state is not a repository observation and does not prove individual ref reachability.
