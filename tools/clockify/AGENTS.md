# Tools/clockify — clockify CLI and local form

Applies on top of the root `AGENTS.md`. Scope: this folder only.

## Shape of the tool

* Everything server-side lives in one file: [src/cli.ts](src/cli.ts). There is no framework, no
  router, no separate "lib" layer — command parsing, Clockify API calls, config/cache file I/O, and
  the local HTTP server for the form all sit in that one script. Keep additions in this style unless
  the file grows enough to justify splitting it; don't introduce a framework to avoid that.
* The web form ([web/src/App.tsx](web/src/App.tsx)) is a single-page React/Tailwind/shadcn app built
  with Vite into `dist/web/`. `dnb-clockify form` serves that built bundle directly — there is no dev
  server in production use.
* **Context injection, not an API round-trip for the first paint**: `serveFormPage()` in `cli.ts`
  reads `dist/web/index.html`, computes a `FormPageContext` object server-side (current projects,
  running entry, last-entry end time, etc.), and injects it as
  `window.__CLOCKIFY_CONTEXT__ = {...}` before `</head>`. `App.tsx` reads that global directly — no
  `fetch()` on load. Any new data the form needs on first paint should extend `FormPageContext` /
  `FormSubmitPayload` and flow through this same injection, not a new endpoint, unless the data must
  be re-fetched after an in-page mutation (see below).
* **The form server is one-shot today**: `commandForm()` starts an HTTP server bound to
  `127.0.0.1:<formPort>` and calls `server.close()` immediately after a successful `/api/submit`. Any
  feature that needs multiple round trips before the final submit (e.g. creating a client or project
  inline, then still submitting the time entry) requires the server to stay alive across more than one
  request — don't assume today's "closes after first POST" behaviour when adding endpoints.
* **`form --restart` runs the actual server as a detached child, not inline.** `restartFormDetached()`
  kills whatever holds the port, spawns a fresh, detached-and-unref'd `form` process, does its own
  lightweight Clockify call to report the current running-timer state, and returns — so the `--restart`
  invocation itself exits immediately instead of blocking like a plain
  `form` call does. A plain `dnb-clockify form` (no `--restart`) still blocks in the foreground until a
  submission closes it; that's unchanged and is why callers like `polybar-clockify` background it with
  `&` themselves. If you add more startup-time reporting to `commandForm`, mirror it in
  `restartFormDetached()` too, since it deliberately doesn't call `commandForm` recursively.
* Clockify is the only source of truth. There is no local database; local files
  (`~/.config/dnb-clockify/config.json`, `~/.cache/dnb-clockify/*.json`) hold only aliases, settings,
  and short-lived caches (status, nudge counter, last-entry-end). Don't cache anything that would let
  the local tool disagree with Clockify about what a client/project/entry actually is.
* Config/cache I/O always goes through `readJsonFile` / `writeJsonFile` (atomic write via a `.tmp`
  file + rename). Reuse these, don't add ad hoc `fs` calls.
* `apiRequest<T>()` is the single fetch wrapper (base URL, `X-Api-Key` header, error handling). Every
  new Clockify endpoint call goes through it.
* CLI commands and form endpoints intentionally share the same helper functions (e.g.
  `resolveProject`, `createEntry`) — when adding client/project management, give the CLI subcommands
  and the form's `/api/*` handlers the same underlying create/update/archive functions rather than
  duplicating request-building logic.

## Clockify API contracts relevant to client/project management

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

## Product decisions for client/project management (confirmed with the user)

* **Delete = archive.** Clockify rejects hard-deleting a client/project that has time entries against
  it. "Delete" in this tool's CLI and form always archives (`archived: true`) rather than calling a
  hard-delete endpoint.
* **Add/edit UI = modal dialog** in the web form, not an inline panel or a separate route. Saving
  closes the dialog and immediately selects the new/edited item in the underlying time-tracking form —
  no page reload.
* **Color picker = fixed swatch grid only** (no free-hex input in v1), matching "single user, don't
  overcomplicate."
* **CLI gets parity in the same pass**: `client`/`project` add/edit/(archive-as-)remove subcommands,
  sharing helper functions with the form's endpoints as described above.
* Hierarchy is top-down: clients have projects, projects have time entries. The "add project" flow
  must offer "add client" inline too (client can be created without leaving the project-creation step).
