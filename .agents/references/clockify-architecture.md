# Clockify implementation context

* Everything server-side lives in one file: [src/cli.ts](../../tools/clockify/src/cli.ts). There is no framework, no
  router, no separate "lib" layer — command parsing, Clockify API calls, config/cache file I/O, and
  the local HTTP server for the form all sit in that one script. Keep additions in this style unless
  the file grows enough to justify splitting it; don't introduce a framework to avoid that.
* The web form ([web/src/App.tsx](../../tools/clockify/web/src/App.tsx)) is a single-page React/Tailwind/shadcn app built
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
