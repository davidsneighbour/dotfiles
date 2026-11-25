---
name: google-alerts
description: Research monitoring topics, propose Google Alerts query families, review imported alerts, and prepare validated local configuration with the Google Alerts Manager CLI.
---

# Google Alerts

Use the standalone CLI from the project root. Read `README.md` for commands and `docs/implementation.md` for browser and reconciliation boundaries.

## Preserve the agreed starting state

The user's Takeout export is the authoritative initial state. Inspect `data/state.json` and `data/topics.yaml` locally when needed. These contain private queries and delivery addresses. Do not publish their values, copy them into public examples, or include them in ordinary reports. Synthetic fixtures live in `tests/fixtures/`.

Preserve imported expressions and all delivery fields unless the user approves a specific change. Link imported queries through `inherit`; global defaults deliberately do not alter these records. Do not interpret negative export hours or map quality values to UI labels without verified evidence. Propose adoption of all existing alerts, but keep adoption separate from query approval and live-change consent. Do not run `adopt --apply` without explicit approval of the concrete current adoption plan.

## Research and propose

For a request such as "track everything about this topic", establish intent, aliases, spellings, languages, relevant sources, exclusions, and likely noise. Ask only about material gaps that cannot be resolved from existing topic intent. Check primary sources and representative recent search results. Distinguish verified findings, inference, and uncertainty. Do not claim exhaustive coverage or assume complex Boolean grouping behaves like a formal query language.

Write a small family of candidate searches with rationales, coverage gaps, overlap risks, research URLs, and notes in the topic's `research` fields. Put proposed searches in `draft`. For changes to an existing imported query, keep its current expression intact until reviewed; describe the proposed expression and evidence in local research notes, or a separate draft query without an inheritance owner. Never duplicate an `inherit` reference across queries.

Research and reviews are manual. Do not create a schedule or background research job. Use clear British English and the confidence labels Verified, Well-established, Inference, Unverified / uncertain, or Estimate when relevant.

## Validate and review

Run `npm run alerts -- validate`, then `npm run alerts -- plan`. Review the private YAML and concise plan with the user. Only after explicit approval, mark the selected queries active and record the reviewer and actual review time. Local configuration approval does not grant ownership or permission to change Google. An overlap is a review suggestion, never grounds to merge or delete automatically. Paused or archived definitions must not cause remote deletion.

The current CLI supports import, local candidate configuration, adoption planning, and offline reconciliation. `sync --apply` deliberately refuses. Report this limit plainly. Do not work around it with direct browser mutations, undocumented endpoints, or hand-made HTTP requests. Later live work requires authenticated account verification, a validated UI adapter, a fresh concrete plan, explicit consent, sequential writes, and post-write verification. Stop on login challenges, ambiguous identities, or unexpected UI behaviour.
