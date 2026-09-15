# Clockify integration handoff

Here is a handoff you can paste into the VS Code Codex task.

writing{variant="standard" id="48291"}
Continue work on the Clockify integration in `/home/patrick/github.com/davidsneighbour/dotfiles`.

Context:

* The repo path is `davidsneighbour`, with the `s`.
* Do not create a branch.
* Do not commit unless explicitly asked.
* Preserve unrelated existing worktree changes.
* Read `AGENTS.md`, applicable `.agents/instructions/**`, and relevant folder README files before editing.

Current implementation:

* New core tool: `/home/patrick/github.com/davidsneighbour/dotfiles/tools/clockify`
* New session wrapper: `/home/patrick/github.com/davidsneighbour/dotfiles/configs/session/clockify`
* New Polybar module: `/home/patrick/github.com/davidsneighbour/dotfiles/configs/session/polybar/configs/07-module-clockify.ini`
* Polybar left side now includes `powermenu clockify i3`.
* Old Clockify traces removed:
  * `~/.clockify-cli.yaml` link removed from `configs/dotbot/config.protected.yaml`
  * `configs/system/launchers/tracking-start.desktop` deleted
  * `configs/system/launchers/tracking-stop.desktop` deleted

Implemented features:

* TypeScript/Node CLI using `CLOCKIFY_TOKEN` from env or `~/.env`.
* Commands: `status`, `projects`, `start`, `stop`, `add`, `edit`, `prompt`, `form`, and `alias`.
* JSON output via `--json`.
* Project aliases stored in `~/.config/dnb-clockify/config.json`, mapped to Clockify project IDs.
* Alias list/set/remove/configure.
* `projects --unmapped`.
* Stale alias detection.
* Resolution order: alias, project ID, exact name, unique case-insensitive name, then error.
* Gum-backed interactive selection when `gum` exists, with plain terminal fallback.
* Local HTML form bound to `127.0.0.1`.
* Status cache around 30 seconds.
* Polybar polls the wrapper every 120 seconds.
* Nudge state with active desktop accumulation and idle exclusion through `xprintidle`.
* Polybar wrapper prints:
  * green Lucide `U+E080` for `healthy`
  * red Lucide `U+E083` for `running`
  * yellow Lucide `U+E082` for `nudge`
  * purple Lucide `U+E4B1` for `error`
* Left click opens the local form. If the form port is already in use, `form --open` reopens the existing local URL instead of failing with `EADDRINUSE`.

Validation already done:

* `npm install` in `tools/clockify` passed.
* `npm run typecheck` in `tools/clockify` passed.
* `npx biome check tools/clockify/src/cli.ts` passed.
* `shellcheck configs/session/clockify/polybar-clockify` passed.
* Targeted Markdown lint passed for touched docs.
* `npm run lint:shell` passed.
* Live read-only Clockify checks passed:
  * `status --json` returned `healthy`
  * `projects --json` returned project data

Known problems / follow-up:

* `npm run check` fails before reaching this tool because `npm run test:shell` currently fails in existing shell tests. Debug showed command substitution path output duplication in `dotfiles-includes-test.sh`.
* `npm run lint:config` has existing YAML failures outside this change.
* `polybar -c configs/session/polybar/config.ini -d modules-left i3bar` is only a config-value dump; in a working X/i3 session it prints `powermenu clockify i3` and exits. It does not start, reload, or visually validate Polybar.
* Visual Polybar validation still needs a real i3/X session. Use `configs/session/polybar/launch.sh` there, then confirm the Clockify indicator appears to the right of the power menu.
* Review the Clockify create/update/stop API calls before relying on write operations heavily. Read-only `status` and `projects` were verified live, but no start/stop/add/edit write operation was executed.

Suggested next steps:

1. Inspect the diff and separate these changes from unrelated existing worktree changes.
2. Run the Clockify CLI in a normal shell:
   * `node --experimental-strip-types tools/clockify/src/cli.ts status --json`
   * `node --experimental-strip-types tools/clockify/src/cli.ts projects --unmapped`
3. Set an alias, for example:
   * `node --experimental-strip-types tools/clockify/src/cli.ts alias set --alias aps --project "asia-pacific-superyachts.com"`
4. Test one controlled write flow with a harmless title, then stop it.
5. Test the form:
   * `node --experimental-strip-types tools/clockify/src/cli.ts form --open`
6. In an i3 session, reload Polybar and confirm the Clockify indicator appears to the right of the power menu.
7. If committing later, use a conventional commit and inspect `.release-it.ts` for valid scopes.
