<!-- vale off -->

# Plan

Recommendations and improvements identified during codebase review. Pick items from here to work on.

## Documentation

* [ ] `docs/setup.md` — strip empty stubs (Discord, Signal, Telegram, Dropbox, Todoist sections), remove crossed-out entries, complete sparse sections
* [ ] `configs/actions/` — add `DOCUMENTATION.md` explaining TOML schema: scopes, activities, `label`, `cmd`, variable expansion
* [ ] `configs/system/autostart/` — add `README.md` explaining `available/` pool, per-host symlink structure, and how `actions autostart-enable` connects
* [ ] `bashrc/lib/00-core/` through `bashrc/lib/50-variables/` — add `DOCUMENTATION.md` per numbered tier explaining what each layer provides and its load-order position
* [ ] cleanup and document `bashrc/cronjobs`
* [ ] cleanup and document `bashrc/helpers`
* [ ] cleanup and document `bashrc/partials`
* [ ] cleanup and deprecate `bashrc/workspaces`
* [ ] document and cleanup `configs`

## Code quality

* [ ] `glone` — wrap the `git ls-remote` SSH availability check in a short timeout; the code has a `# NOTE:` flagging it as a potential hang with misconfigured SSH agents
* [ ] `glone_clone_one` — promote nested inner function to a `_glone_clone_one` top-level private function for testability and clarity
* [ ] `bashrc/helpers/docker/backup-runner` — consolidate the three parallel formats (no-ext compiled, `.mjs`, `.ts`) into a single canonical `.ts` version; all three currently define identical function sets
* [ ] `actions.sh` `source_core_libs` — missing core lib should be a hard failure, not a silent skip via `|| continue`

## Enhancements

* [ ] `configs/actions/actions.toml` — add scopes for: wallpaper selection (wraps `set-wallpaper.sh`), theme switching, docker container update, workspace layout setup, autostart management
* [ ] Dotbot per-host autostart — add autostart symlink steps to `config.host-locutus.yaml` and `config.host-hal2025.yaml` so autostarts are configured idempotently on each `dotbot` run
* [ ] unified container update helper — script or `actions.toml` scope that iterates `containers/<host>/*/` and runs each `update.sh`
* [ ] `glone` post-clone hooks — `--post-clone` mechanism for running `npm install`, `git submodule update`, project init scripts after a successful clone

## Infrastructure / containers

* [ ] add health checks and explicit `restart: unless-stopped` policies to container compose files, starting with `openwebui` (proxies to native Ollama; no retry on Ollama unavailability)
* [ ] shared base compose for the `locutus`/`hal2025` service overlap (metube, owntrack, paperless, readeck run on both; configs can drift silently without a common base)

## Bugs / investigations

* [ ] `@dnbhq/markdownlint-config` not applying correctly when extended via `.markdownlint.jsonc` — line-length rule fires even though it is disabled in the shared config; see `scratch/job.md` for full reproduction steps
* [ ] `zoxide` — listed as optional init in bashrc docs; verify whether the current bashrc init is sufficient or needs further wiring
