# Delivery report

Date: 23 November 2026.

**Verified:** M1 and M2 are implemented and tested against the uploaded Takeout archive. The project also includes offline adoption and reconciliation, an agent skill, a preliminary Playwright probe, and a detailed plan for authenticated discovery and safe synchronisation.

## Actual archive verification

The archive `takeout-20261122T224731Z-1-001.zip` was recovered from the referenced chat attachment because `/mnt/data` does not exist in this environment. Its contents were inspected before implementation. The ZIP contains one subscriptions JSON file with nine records. The export is treated as the authoritative starting state, as instructed by the user.

Direct assertions verified that the private state contains all nine exact records, the candidate YAML resolves to those same records without loss, and the saved raw snapshot is byte-identical to the JSON in the archive. Re-import returned `changed: false`. There are no exact duplicate records. No automatic semantic merging, timing normalisation, delivery conversion, or query improvement was performed.

The working copy contains `data/state.json`, `data/snapshots/`, `data/topics.yaml`, `data/adoption-plan.json`, and `data/initial-plan.json`. There are nine draft topic wrappers and nine unchanged queries. Topic grouping is left for manual review. The adoption plan proposes all nine; managed ownership remains empty. The source archive deliberately excludes these private files and browser data.

## Files delivered

| File or directory | Purpose |
| --- | --- |
| `src/cli.ts` | Standalone native TypeScript CLI with dry-run defaults and withheld private errors. |
| `src/takeout.ts` | Safe ZIP or JSON importer with size limits, CRC checks, and actual-schema validation. |
| `src/model.ts`, `src/store.ts` | Deterministic IDs, lossless records, immutable snapshots, state validation, locks, atomic writes, and private permissions. |
| `src/config.ts`, `config/schema.json` | Zod/YAML topic model, manual approval, defaults, and inheritance. |
| `src/reconcile.ts` | Adoption proposals, digest-bound local approval, and three-way offline plans. |
| `src/browser.ts` | Dedicated-profile read-only diagnostic probe and explicit refusal of live synchronisation. |
| `tests/core.test.ts`, `tests/fixtures/takeout.synthetic.json` | Regression tests and an actual-shape fixture with entirely synthetic queries and addresses. |
| `.agents/skills/google-alerts/SKILL.md` | Manual topic research, query review, privacy, approval boundaries, and CLI workflow. |
| `README.md`, `docs/implementation.md` | Setup, commands, operating limits, verified schema, milestone criteria, and browser execution design. |
| `package.json`, `package-lock.json`, `tsconfig.json` | Pinned npm dependencies, Node 24+ requirement, and strict TypeScript checks. |

## Verification results

**Verified:** `npm run check` passes strict type checking and all 18 tests under Node `26.13.1`. The same 18 tests pass with the installed Node `24.22.1` binary. No transpiler is used to run the CLI or tests. Other Node 24 minor versions were not tested.

The tests cover actual-schema fidelity, negative hours, unrestricted regions, equivalent ZIP/JSON identity, exact raw snapshots, repeated imports, unchanged initial truth after later imports, unknown fields, duplicate preservation, malformed input, UTF-8, payload limits, missing ZIP entries, duplicate target entries, symlinks, traversal, inflation, CRC damage, exclusive files, locks, corrupt state, inheritance, strict YAML, duplicate ownership, manual review, delivery requirements, approval digest mismatch, all comparison outcomes, remote convergence, identity ambiguity, snapshot corruption, ordinary-output privacy, and refusal of live apply.

A clean installation from the source archive also passes type checking and all 18 tests. The skill validator passes. The synthetic example configuration validates. The production dependency audit reported zero known vulnerabilities at verification time. A scan of public source files found no full exported queries, exported email addresses, or the exact-name query value. The fixture uses reserved `.invalid` addresses and synthetic search expressions. No private state, original archive, browser profile, or installed dependencies are included in the distributable archive.

## Remaining work

**Unverified / uncertain:** The actual authenticated Google Alerts interface, available provider IDs, UI labels for raw quality values, and preservation of all delivery-time settings through browser edits have not been inspected. The export remains the accepted initial truth; browser verification is required before future live writes.

M3 has a probe and specification, but no verified discovery adapter. M4 works offline; browser-backed matching remains. M5 is specified and disabled. M6 has the requested skill. M7 includes offline hardening and documentation, but live UI regression fixtures, an execution journal, interrupted-write recovery, and authenticated acceptance tests remain.

No Google account browser session was opened during this implementation. No live alert was created, edited, or deleted. No ownership approval was applied to the actual inventory. `sync --apply` refuses immediately. The next practical step is manual review of the private candidate YAML and adoption proposal, followed by separately authorised authenticated read-only browser discovery.
