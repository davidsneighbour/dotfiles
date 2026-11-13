# Clockify workstation tool

`tools/clockify` contains a small Clockify CLI for workstation time tracking. It is deliberately local, uses the Clockify API directly, and keeps UI/session glue outside the core tool.

The command reads `CLOCKIFY_TOKEN` from the environment. If the variable is not already set, it also reads `~/.env` and extracts `CLOCKIFY_TOKEN` from there. The token is never printed.

## Install and run

Install dependencies once:

```bash
npm install
```

Run commands from this folder:

```bash
npm start -- status
npm start -- projects
npm start -- start --project aps --title "Write deployment notes"
```

For a global helper, link `src/cli.ts` through your local bin path or call it with Node from shell glue.

### Local form assets

`dnb-clockify form` serves a small React/Tailwind/shadcn UI built with Vite. Build it once, and again after changing anything under `web/`:

```bash
npm run build
```

`npm run dev` starts a Vite dev server for iterating on the form's styling in isolation. `npm run typecheck` checks both the CLI (`tsconfig.json`) and the form (`web/tsconfig.json`).

## Commands

```bash
dnb-clockify status
dnb-clockify projects
dnb-clockify projects --unmapped
dnb-clockify projects add --name <name> --client <client-id|name> [--color <hex>]
dnb-clockify projects edit --id <project-id> [--name <name>] [--client <client-id|name>] [--color <hex>]
dnb-clockify projects remove --id <project-id>
dnb-clockify client list
dnb-clockify client add --name <name>
dnb-clockify client edit --id <client-id> --name <name>
dnb-clockify client remove --id <client-id>
dnb-clockify start --project <alias|id|name> --title <text>
dnb-clockify stop [--title <text>] [--project <alias|id|name>]
dnb-clockify add --project <alias|id|name> --title <text> --start <time> --end <time>
dnb-clockify edit --id <entry-id> [--project <alias|id|name>] [--title <text>] [--start <time>] [--end <time>]
dnb-clockify prompt
dnb-clockify form [--open] [--restart]
dnb-clockify alias list
dnb-clockify alias set --alias <short-name> --project <project>
dnb-clockify alias remove --alias <short-name>
dnb-clockify alias configure
```

Client and project "removal" always archives — Clockify rejects hard-deleting a client or project
that has time entries logged against it, so this tool never attempts that. `projects edit`/`client
edit` only change the fields you pass; omitted fields keep their current value.

Add `--json` to commands when another tool or agent should parse the result. JSON responses use stable top-level `ok`, `command`, and `data` fields on success, and `ok`, `command`, and `error` fields on failure.

## Project aliases

Aliases are stored in `~/.config/dnb-clockify/config.json`. Each alias maps to a Clockify project ID. The cached project name is only for readability and stale-alias checks.

Project resolution order is:

1. alias
2. project ID
3. exact project name
4. unique case-insensitive project name
5. error, or interactive selection when a prompt command is being used

Use these commands:

```bash
dnb-clockify alias set --alias aps --project "asia-pacific-superyachts.com"
dnb-clockify alias list
dnb-clockify projects --unmapped
dnb-clockify alias remove --alias aps
```

`alias list` marks aliases as stale when the stored project ID no longer appears in the current Clockify project list or when the project name changed.

## Interactive prompt

`dnb-clockify prompt` prefers `gum` when it is installed. Project selection is searchable through `gum filter`; otherwise the command falls back to plain terminal prompts.

The interactive flow can start a timer, stop the running timer, or create a completed manual entry.

## Local HTML form

`dnb-clockify form` starts a one-shot local HTTP server bound to `127.0.0.1`. It prints the URL and waits for one submission. Run `npm run build` first — the command exits with an error pointing at that command if `dist/web/index.html` doesn't exist yet.

Each time the server actually starts (not when it reuses an already-running one), it queries Clockify for the current running timer and prints the result (`Timer running: <title>` or `No timer running.`, or `running: true/false` with `--json`). This check is always live — the local server process holds no state of its own about the timer, so it's safe to kill and restart (see `--restart` below) at any time; the next start just re-checks Clockify directly.

If the configured `formPort` is already in use, `form` reuses the existing server's URL instead of starting a new one. Pass `--restart` to instead kill whatever process is bound to that port (via `lsof`) and start a fresh server — useful if a previous form server is stuck, or after changing this tool's code while a server from before the change is still running.

Unlike a plain `form` invocation (which blocks in the foreground until a submission happens, since the CLI process is the server), `--restart` spawns the fresh server as a detached background process and the `form --restart` command itself exits immediately after printing the URL and current timer state. It's meant to be run directly in a terminal without `&`.

With no running timer, the form pre-fills `start` with the current time and leaves `end` empty. Submitting with an empty `end` starts a timer. Submitting with `end` set creates a completed entry.

With a running timer, the form pre-fills the current title, project, and start time, and sets `end` to now. Submitting with `end` set updates and stops the timer. Clearing `end` updates the running entry and keeps it running.

Two quick-fill links sit next to the `start` field: "From last entry" sets `start` to the end of the most recent completed entry, and "Now" sets it to the current time. The last-entry end comes from the local tracking state. Clockify updates it when the lists are refreshed, and local entry changes update it without an API call.

Two links next to the "Project" field, "Clients" and "Projects", open small dialogs to add, rename,
or archive ("Delete") clients and projects without leaving the form. Creating a project requires
picking a client; the project dialog has its own "+ new client" shortcut so you never have to back
out of it to create one first. Colors are chosen from a fixed swatch grid rather than typed in.
Saving updates the form immediately — no reload — and creating a new project selects it right away
in the time-tracking form above.

Entries created or stopped through the form get a `via:form` tag. Starting a timer or creating a completed entry (an "open") tags it; stopping a running timer (a "close") adds the tag to whatever tags the entry already had. Editing a running entry without stopping it does not change its tags. The `via:form` tag is created in the Clockify workspace the first time it's needed.

### Tag classes

The form offers the initial `for:`, `type:`, `domain:`, `activity:`, `channel:`, `purpose:`, `context:`, and `via:` vocabulary. Each class has a Dracula colour and its own row. Rows show the first three options and any selected tags; **More** shows every option in that class, and **Less** collapses it again. Existing tags with other prefixes remain available in their own uncoloured row.

Exactly one `for:` and one `type:` tag are required when submitting the form. Selecting another value replaces the current selection in either class, and in `activity:`. An activity is recommended; the remaining classes are optional and allow several values. Existing selections are retained when opening a running entry, including older tags.

Suggested tags are created in Clockify only when submitted. **New tag** accepts a class through radio buttons and a value without the prefix. The edit button beside a workspace tag opens the same controls; saving renames that shared tag across all entries that use it. Custom values are allowed, so the initial vocabulary is extensible. These controls apply to the local form; CLI entry commands retain their existing behaviour. The automatic, reserved `via:form` marker remains unchanged.

## Nudge and status

`status` reads only the local tracking state in `~/.cache/dnb-clockify/tracking-state.json`. It sends no API requests, so Polybar can call it every minute. It also tracks active desktop time while no timer is running. Idle time is ignored when `xprintidle` is available. `status --sync` first asks Clockify for a running timer (one request), then prints the status.

The local tracking state holds the running timer, the end of the latest completed entry, the time of the last online check, and the time of the last local entry change. These events update it:

* `start`, `stop`, `add`, `edit`, `prompt`, and form submits record the entry that Clockify returns. They also reset the local nudge counter and refresh Polybar.
* Opening the form, a form submit, `stop`, `prompt`, `form --restart`, and `status --sync` ask Clockify for the running timer.
* When the form window gets focus again, the form asks the local server for the running timer. If the timer changed, the form shows a **Reload** prompt. A submit is refused when the timer changed after the form opened.

A timer started or stopped in another Clockify client is visible only after the next online check, for example the next time you open the form.

## API rate limits

The Clockify Free plan allows 30 API requests per hour per workspace. The tool counts every request in a rolling one-hour ledger in `~/.cache/dnb-clockify/rate-limit.json` and refuses requests that exceed `apiRequestsPerHour`. If Clockify still answers with HTTP 429, all requests stop for one hour. A refused request reports when the next request is possible.

These measures keep the request count low:

* The user and workspace IDs are cached in `identity.json`. They are fetched again only if the token or the configured `workspaceId` changes.
* Projects, clients, tags, and recent entries are cached in `lists.json` for `listCacheSeconds`. Form changes to clients, projects, and tags update this cache. CLI commands resolve projects from a fresh cache before they ask Clockify.
* Running checks are skipped when the last check is younger than `runningCheckSeconds`.
* Optional requests keep 5 requests in reserve for entry changes. The focus check and the list refresh are optional. If the lists cache is stale and the budget is low, the form uses the stale lists.
* If a running check is refused, the form uses the local state and shows a notice.

If the form cannot load its data, for example because of a rate limit, the window shows an error page in the form design. The page shows the error message and the formatted details: the Clockify response body or the local budget values. **Open Clockify website and close** opens `https://app.clockify.me/tracker` in the default browser, closes the window, and stops the form server. The CLI prints the same details below the error message, and `--json` output includes them as `details`.

Opening the form normally costs one request. A submit costs one more, plus the list refresh once per `listCacheSeconds` (4 requests).

Configurable settings live under `settings` in `~/.config/dnb-clockify/config.json`:

```json
{
  "settings": {
    "nudgeMinutes": 60,
    "idleSeconds": 300,
    "formPort": 39241,
    "apiRequestsPerHour": 30,
    "listCacheSeconds": 3600,
    "runningCheckSeconds": 60
  },
  "aliases": {}
}
```

Status states:

| State | Meaning |
| --- | --- |
| `healthy` | No timer is running, by the local tracking state. |
| `running` | A Clockify timer is running, by the local tracking state. |
| `nudge` | No timer is running, and active desktop time exceeded the nudge threshold. |
| `error` | Missing token, or a failed `status --sync` request. |

Use a higher `apiRequestsPerHour` only if the workspace has a paid plan.

## V1 limits

This first version intentionally skips billing controls, reports, project inference, and a database. Clockify remains the source of truth.

The Polybar integration enables `status --remind` and polls every 60 seconds for full-hour Dunst reminders after an hour without tracking. The reminder reads only the local tracking state. A running timer, an entry that ended in the past hour, or a local entry change in the past hour suppresses it. See [Clockify session integration](../../configs/session/clockify/README.md) for timing, idle behaviour, and cache details.
