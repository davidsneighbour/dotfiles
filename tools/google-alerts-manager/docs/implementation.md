# Implementation specification and milestones

## Decisions and state model

The supplied Takeout export is the authoritative initial state by user instruction. Delivery is preserved, all existing subscriptions are proposed for adoption, and query reviews are manual. Ownership approval, query approval, and live-change consent are separate decisions. No live ownership or delivery changes were made.

The hybrid boundary is an agent skill for intent, research, and review, plus a deterministic CLI for validation, ownership, comparison, and eventually verified browser interactions. The runtime is Node 24+ with native TypeScript, ESM, strict type checking, npm, Zod, YAML, yauzl, and Playwright. There is no agent-provider dependency and no build step.

`state.json` stores the immutable initial inventory, import manifest, and separately approved managed baselines. Exact raw JSON payloads are archived privately. Fingerprints cover all record fields, including unknown fields, without semantic query normalisation. Exact duplicates get separate occurrence IDs and block automatic adoption. Local IDs must never be treated as provider identities. Later exports are archived without changing initial truth. A future baseline update requires an explicit reviewed operation.

## Verified export contract

The actual ZIP has one entry: `Takeout/Alerts/ALERTS-SUBSCRIPTIONS.JSON`. Its root has a `subscriptions` array containing nine objects. Observed fields are `query`, `language`, `country`, `applyLanguageRestrict`, `applyRegionRestrict`, `quality`, `deliveryMethod`, `deliveryFrequency`, `deliveryTime`, and `emailAddress`. The time object contains `timezoneCode`, `hourOfDay`, and `dayOfWeek`.

All nine subscriptions use email, English, language restriction enabled, country `US`, and region restriction disabled. Eight are daily and one is hourly. Quality is `HIGH` for eight and `LOW` for one. Six time objects have hour `-3`, two have hour `5`, and one has hour `0`. All observed timezone codes are `Etc/GMT`, and day-of-week values are `0`. None of these values are reinterpreted.

[Google's schema reference](https://developers.google.com/data-portability/schema-reference/alerts) describes the field meanings, optional fields, sources, quality, and delivery, but uses snake_case names and describes quality as a list. The actual uploaded JSON uses camelCase names and a scalar quality string. The implemented importer follows the actual archive; it accepts scalar or array quality values and preserves unknown fields. It does not silently convert an unobserved alternative schema. This is an intentional distinction between documented field meaning and verified export representation.

The ZIP reader does not extract files. It rejects unsafe names, symlinks, encryption, duplicate target entries, unsupported target compression, oversized payloads, excessive entry counts, bad declared sizes, and incorrect CRC. Limits are 128 MiB for the input file, 8 MiB for subscriptions JSON, 10,000 ZIP entries, and 10,000 records. JSON parsing requires valid UTF-8. Root metadata is retained in the exact raw snapshot. Same payload imports do not duplicate inventory or change state bytes.

## Configuration and comparison

The strict versioned YAML schema separates topic intent, research provenance, query expression, manual review, and overrides. Queries have draft, active, or paused status. Topics can be active or archived. Global defaults apply only to new queries. Imported queries inherit their raw baseline, with explicit topic and query overrides taking precedence. New active email alerts require a destination and frequency. The JSON Schema is generated from the same Zod model.

The comparison engine produces `create`, `update`, `unchanged`, `adopt`, `conflict`, `missing`, `unmanaged`, `delete-proposed`, and `paused` operations. The plan digest covers desired records, observed records, operations, and ownership. It is a review identifier, not a signature. Current plans are not executable.

Matching uses a previously verified provider ID if stored; otherwise it requires a unique exact full baseline fingerprint. When no stable ID is available, changed remote records cannot safely be attributed to a baseline, so the result is missing plus unmanaged rather than a guessed match. Duplicate matches and duplicate desired targets produce conflicts. If an identified remote record differs from both the baseline and desired state, it is a conflict. If it already equals desired state, it is unchanged. Definitions removed from configuration produce deletion proposals only. Missing managed alerts are never recreated automatically.

A future browser inventory must have this shape and satisfy `observationSchema`:

```json
{
  "schemaVersion": 1,
  "origin": "browser",
  "capturedAt": "2026-11-23T00:00:00Z",
  "accountVerified": true,
  "alerts": [
    { "providerId": "optional-verified-ui-identity", "record": { "query": "synthetic example" } }
  ]
}
```

The example shows structure only. It is not a complete record suitable for live writes. An adapter must read all supported settings, retain unsupported settings as opaque data, and block changes if preservation cannot be demonstrated. A user-supplied JSON file does not itself prove account verification.

## Milestones and acceptance

| Milestone | Delivered status | Acceptance and remaining work |
| --- | --- | --- |
| M1: Takeout importer | Complete | Actual ZIP inspected, nine records preserved, unknown fields retained, safe ZIP limits and CRC checked, and repeated import verified unchanged. |
| M2: Configuration and state | Complete | Zod-validated YAML, defaults, inheritance, private snapshots, atomic state, locking, synthetic fixtures, and tests are implemented. |
| M3: Browser discovery | Preliminary probe and specification | Dedicated Playwright profile and private diagnostic capture exist. Manual authentication, account verification, exact settings read-back, and unique row identity mapping still need authenticated UI evidence. |
| M4: Adoption and reconciliation | Offline implementation complete | All-nine adoption proposal and digest-bound local approval exist. Three-way plans and conflict tests work. Adoption has not been approved or applied in the delivered private state. Browser-backed identity and baseline verification remain. |
| M5: Playwright sync | Designed; deliberately disabled | No create, edit, or delete adapter is enabled. `sync --apply` fails before opening a browser. Complete the verified execution workflow below before enabling it. |
| M6: Agent skill | Implemented | Intent research, query families, manual review, local validation, privacy, and CLI hand-off are documented in the discoverable skill. No real query research was requested or performed during this build. |
| M7: Hardening and documentation | Partial | Regression tests, strict schemas, private permissions, fail-closed errors, source packaging, and operating guidance are delivered. Live UI tests, write journal recovery, and real browser diagnostics remain. |

## Browser discovery work

Use a dedicated persistent Chromium profile, as supported by [Playwright's persistent-context API](https://playwright.dev/docs/api/class-browsertype#browser-type-launch-persistent-context). The current `browser-probe` is development scaffolding: it captures controls privately and does not claim authentication or enumerate settings. No production selectors have been invented from memory.

The next session needs a manual sign-in flow and read-only account confirmation. Record the account privately, bind subsequent observations to it, and abort if the account changes. Inspect Google Alerts rows and each edit panel without saving; learn accessible roles, labels, identity attributes, option values, and timing behaviour. Verify whether complete delivery settings can be read and preserved through the UI. Cancel panels and prove no changes were saved. Create sanitised HTML fixtures only after replacing personal content, addresses, identifiers, and account data. A successful discovery must match each imported record uniquely or report unresolved records without changing the authoritative starting inventory.

Stop on authentication challenges, CAPTCHA, absent controls, multiple matches, or uncertain account identity. Do not bypass these conditions. A probe failure does not license a guessed adapter.

## Future apply and recovery workflow

1. Read and verify the authenticated account and current complete inventory under the process lock.
2. Reconcile against the managed baseline and approved desired YAML. Block all unresolved conflicts, missing records, unknown setting mappings, and ambiguous identities.
3. Present a concrete plan. Bind explicit consent to its digest, account, and freshness. Require `--apply` plus that approved plan; the flag alone is not evidence of consent.
4. Re-read immediately before execution. Reject the plan if the account or relevant inventory changed. Create a durable private journal with before state, desired state, and operation IDs before any write.
5. Apply one operation at a time through a versioned UI adapter. Imported updates must preserve every delivery setting or stop. Deletion requires separate explicit consent and must never include unmanaged alerts.
6. Re-read the affected alert independently and compare complete supported settings before committing the new baseline. A click or navigation success is insufficient.
7. On failure, stop the batch. Keep sanitised ordinary diagnostics and private opt-in screenshots or DOM evidence. Do not retry an uncertain write blindly.
8. On restart, inspect remote state against the pending journal. Classify each operation as applied, unapplied, or ambiguous before continuing. Never automatically roll back by deleting an alert.

Test the adapter against synthetic local UI fixtures first. Then run read-only authenticated acceptance. Live create/edit acceptance needs separate consent for a disposable test alert, verified account identity, and an agreed clean-up plan. Existing alerts must not be used as destructive tests.
