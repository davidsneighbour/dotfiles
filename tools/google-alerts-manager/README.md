# Google Alerts Manager

A standalone Node 24+ CLI with native TypeScript execution, YAML configuration, and manual agent research. It imports Google Takeout without contacting Google. The supplied export is the authoritative starting state. Importing it does not approve management ownership or live changes.

## Start

```bash
npm ci
npm run check
npm run alerts -- import --from-takeout /path/to/takeout.zip
npm run alerts -- import --from-takeout /path/to/takeout.zip --apply
npm run alerts -- topics --apply
npm run alerts -- validate
npm run alerts -- inventory
npm run alerts -- adoption-plan
npm run alerts -- plan
```

The tool lives in the dotfiles repository at `tools/google-alerts-manager/` and is an npm workspace of the root project. Run `npm run alerts` from this folder. `node src/cli.ts …` works without a build step and from any directory.

The working copy already contains the actual nine-alert baseline and draft YAML under `data/`. Git ignores this folder, so private state is never committed. Repeating the import changes no state. `topics --apply` writes `data/topics.yaml` once and refuses to overwrite an existing file.

## Ownership and review

`adoption-plan` proposes all unambiguous imported alerts. Review the private imported records and candidate YAML before approving. The displayed digest binds approval to the current adoption plan. To record ownership locally, use the following command with the reviewed digest:

```bash
npm run alerts -- adopt --all --approve REVIEWED_DIGEST --apply
```

Do not run this merely because a previous instruction proposed adoption. The current delivery explicitly leaves ownership unapproved. Exact duplicate records block bulk adoption. Adoption does not contact Google, activate queries, or change delivery.

Candidate queries start as `draft`. A manual review must set `status: active` and add `review: { approved: true, reviewer: local-user, at: '2026-11-23T00:00:00Z' }`. Use the actual review time. This is a local review attestation, not cryptographic proof of consent. Topic research and query reviews run only when requested. See the [agent skill](.agents/skills/google-alerts/SKILL.md).

## Configuration

See [the synthetic example](config/example.yaml) and [the JSON Schema](config/schema.json). Supply a different file with `--config FILE`. The root document has `schemaVersion`, `defaults`, and `topics`; each topic contains intent and multiple queries. IDs must be unique. Unknown configuration keys fail validation.

New queries inherit global defaults, topic settings, and then query settings. Imported queries use `inherit: import-…` to retain their entire original subscription, including unknown fields. Global defaults do not override an imported subscription. Explicit topic settings and query settings can override individual fields. Delivery time is a complete object when overridden; there is no partial time merge. Keep email addresses and personal queries in `data/`, rather than public configuration files.

The importer deliberately preserves export values. `HIGH` and `LOW` are not mapped to UI labels. Negative delivery hours are not normalised. A country value does not imply region restriction. Raw records can contain future Google fields, while configuration overrides accept only supported settings.

## Plans and browser work

`plan` and `sync` default to offline dry runs against the authoritative Takeout baseline. Their output states its source and is marked `executable: false`. A draft or paused query causes no live deletion. Removing a managed definition produces a deletion proposal only. Unmanaged alerts remain unowned. Ambiguous identity, remote drift, and missing alerts block safe updates. No query-only fuzzy matching is used.

For future adapter development, `--observed FILE` accepts a Zod-validated private browser inventory; see [the implementation specification](docs/implementation.md). A supplied `accountVerified: true` is an assertion from that adapter or operator, not verification performed by this CLI. Such observations can inform offline plans, but cannot authorise writes.

A preliminary Playwright diagnostic command exists:

```bash
npm exec playwright install chromium
npm run alerts -- browser-probe
npm run alerts -- browser-probe --apply
```

The explicit flag opens a dedicated persistent profile and saves private control metadata. This probe neither authenticates the account nor builds a verified alert inventory. It stops on a login redirect. No browser command was run against the user's account during implementation. A future manual login workflow and validated account checks are needed before discovery is complete.

`sync --apply` always refuses. Browser discovery and live writes are intentionally incomplete because authenticated UI evidence and verified live-change consent are absent. The CLI has no alert create, edit, or delete interactions. See the remaining milestone criteria before enabling them.

## Private state and recovery

All private state is in `data/` in the tool folder. The CLI finds this folder from its own location, not from the current directory; use `--state-dir DIR` to choose a different folder. Git ignores `data/`, and nothing else backs it up. To rebuild it, import the Takeout export again; manual edits to `topics.yaml` are then lost. The folder contains exact immutable import snapshots, `state.json`, generated topic YAML, and any browser profile or diagnostic capture. Files use mode `0600`, and managed directories use `0700`. This protects against other local users; it is not encryption. Backups and the same operating-system account can still read it.

Import snapshots are stored by SHA-256 payload digest, and are never overwritten by normal imports. Initial alert identities use full canonical record hashes plus duplicate occurrence numbers; these are local IDs, not Google IDs. Later imports are archived separately and never silently replace the authoritative initial baseline or managed baselines. State writes use an exclusive process lock and atomic rename. A stale `write.lock` requires checking that the previous process has stopped before removal. Do not automatically delete a lock or reset corrupt state. Version 1 state is validated; unsupported versions fail rather than migrate silently.

Ordinary command output omits raw records and queries. Library errors are withheld. Inspect private files locally when reviewing queries and delivery. Browser controls may contain personal data; they are private diagnostic evidence and must not be copied into fixtures without sanitisation. No screenshots are currently captured.

## Verification

```bash
npm run check
node --version
node --test tests/core.test.ts
```

Tests use synthetic queries and `.invalid` addresses. ZIP tests generate their own archives. Read [the delivery report](docs/delivery-report.md) for actual-archive verification and milestone status.
