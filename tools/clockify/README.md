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
dnb-clockify start --project <alias|id|name> --title <text>
dnb-clockify stop [--title <text>] [--project <alias|id|name>]
dnb-clockify add --project <alias|id|name> --title <text> --start <time> --end <time>
dnb-clockify edit --id <entry-id> [--project <alias|id|name>] [--title <text>] [--start <time>] [--end <time>]
dnb-clockify prompt
dnb-clockify form [--open]
dnb-clockify alias list
dnb-clockify alias set --alias <short-name> --project <project>
dnb-clockify alias remove --alias <short-name>
dnb-clockify alias configure
```

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

With no running timer, the form pre-fills `start` with the current time and leaves `end` empty. Submitting with an empty `end` starts a timer. Submitting with `end` set creates a completed entry.

With a running timer, the form pre-fills the current title, project, and start time, and sets `end` to now. Submitting with `end` set updates and stops the timer. Clearing `end` updates the running entry and keeps it running.

## Nudge and status

`status` queries Clockify and uses a short cache, defaulting to 30 seconds, so Polybar can call it often without hammering the API. It also tracks active desktop time while no timer is running. Idle time is ignored when `xprintidle` is available.

Successful time-entry changes reset both the short status cache and the local nudge counter. This means a yellow `nudge` state returns to `healthy` after you submit a completed manual entry, unless Clockify reports a running timer or an error.

Configurable settings live under `settings` in `~/.config/dnb-clockify/config.json`:

```json
{
  "settings": {
    "cacheSeconds": 30,
    "nudgeMinutes": 60,
    "idleSeconds": 300,
    "formPort": 39241
  },
  "aliases": {}
}
```

Status states:

| State | Meaning |
| --- | --- |
| `healthy` | Clockify is reachable, and no timer is running. |
| `running` | A Clockify timer is running. |
| `nudge` | No timer is running, and active desktop time exceeded the nudge threshold. |
| `error` | Token, network, or API problem. |

## V1 limits

This first version intentionally skips tags, billing controls, reports, project inference, and a database. Clockify remains the source of truth.
