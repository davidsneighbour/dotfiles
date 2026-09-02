<!-- vale off -->

# Plan

Recommendations and improvements identified during codebase review. Pick items from here to work on.

## Documentation

* [x] `docs/setup.md` — strip empty stubs (Discord, Signal, Telegram, Dropbox, Todoist sections), remove crossed-out entries, complete sparse sections
* [ ] `bashrc/lib/00-core/` through `bashrc/lib/50-variables/` — add `DOCUMENTATION.md` per numbered tier explaining what each layer provides and its load-order position
* [ ] cleanup and document `bashrc/cronjobs`
* [ ] cleanup and document `bashrc/helpers`
* [ ] cleanup and document `bashrc/partials`
* [ ] document and cleanup `configs`

## Code quality

* [x] `glone` — wrap the `git ls-remote` SSH availability check in a short timeout; the code has a `# NOTE:` flagging it as a potential hang with misconfigured SSH agents
* [x] `glone_clone_one` — promote nested inner function to a `_glone_clone_one` top-level private function for testability and clarity
* [x] `bashrc/helpers/docker/backup-runner` — consolidate the three parallel formats (no-ext compiled, `.mjs`, `.ts`) into a single canonical `.ts` version; all three currently define identical function sets

## Enhancements

* [ ] unified container update helper — script that iterates `containers/<host>/*/` and runs each `update.sh`
* [ ] `glone` post-clone hooks — `--post-clone` mechanism for running `npm install`, `git submodule update`, project init scripts after a successful clone

## Infrastructure / containers

* [ ] add health checks and explicit `restart: unless-stopped` policies to container compose files, starting with `openwebui` (proxies to native Ollama; no retry on Ollama unavailability)
* [ ] shared base compose for the `locutus`/`hal2025` service overlap (metube, owntrack, paperless, readeck run on both; configs can drift silently without a common base)

## Bugs / investigations

* [ ] `@dnbhq/markdownlint-config` not applying correctly when extended via `.markdownlint.jsonc` — line-length rule fires even though it is disabled in the shared config; see `scratch/job.md` for full reproduction steps
* [x] `zoxide` — bashrc init is sufficient; fixed silent-failure logging and switched the install script to `fetch-and-run.sh` (see #492)
