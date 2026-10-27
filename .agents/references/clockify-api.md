# Clockify client and project API notes

These are preserved historical observations, not fresh API verification. Recheck official documentation and current implementation before changing API behaviour.

Verified against `https://docs.clockify.me/` (clients) and cross-checked with the third-party
`real-art/clockify-ts` TypeScript SDK's type definitions (both clients and projects) on 2026-09-20.
The official docs page truncated before the full project request body, so the project fields below
are corroborated by the SDK's types, not the primary source directly — treat as well-established
rather than fully verified against the primary doc.

**Clients** — `/workspaces/{workspaceId}/clients`

* `POST` body: `name` (string, required, 0–100 chars). Optional: `email`, `address`, `note`,
  `currencyId`, `ccEmails` (array, max 3).
* `PUT /{id}` body: same optional fields, plus `archived` (boolean) — this is how a client is
  archived, there is no separate archive endpoint. Query param `archive-projects=true` also archives
  all of that client's projects in the same call.
* No hard-delete path is used by this tool (see "Delete = archive" decision below).

**Projects** — `/workspaces/{workspaceId}/projects`

* `POST` body: `name` (required). Optional: `clientId`, `isPublic`, `color`, `note`, `billable`,
  `public`.
* `PUT /{id}` body: `name` (required), `archived` (required boolean — this is how a project is
  archived), plus optional `clientId`, `isPublic`, `hourlyRate` (`{amount, currency}`), `color`,
  `note`, `billable`, `public`.
* `color` is a free-form hex string (e.g. `"#1976D2"`), not a fixed enum on Clockify's side. A
  predefined swatch grid in this tool's UI is a local UX choice, not an API constraint — any hex value
  Clockify accepts can be sent.
* **Verified live against the production workspace on 2026-09-20**: `PUT /projects/{id}` returns
  `403 "You don't have permission to perform this action."` if `isPublic` and `billable` are omitted
  from the body — even though `POST /projects` (create) works fine without them, and even though
  they aren't documented as required for update. `updateProject()` in `cli.ts` always sends
  `isPublic: current.public ?? true` and `billable: current.billable ?? true` sourced from the
  project's current state, so edits that only touch name/client/color/archived don't silently flip
  these fields. If you ever see this same 403 on a Clockify `PUT`, suspect a missing field the
  official docs didn't mention rather than a real permissions problem — this account is the
  workspace owner.
