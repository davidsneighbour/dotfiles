<!-- vale off -->

# Plan

Recommendations and improvements identified during codebase review. Pick items from here to work on.

## Documentation

* [ ] `bashrc/lib/00-core/` through `bashrc/lib/50-variables/` — add `DOCUMENTATION.md` per numbered tier explaining what each layer provides and its load-order position
* [ ] cleanup and document `bashrc/cronjobs`
* [ ] cleanup and document `bashrc/helpers`
* [ ] cleanup and document `bashrc/partials`
* [ ] document and cleanup `configs`

## Enhancements

* [ ] unified container update helper — script that iterates `containers/<host>/*/` and runs each `update.sh`
* [ ] `glone` post-clone hooks — `--post-clone` mechanism for running `npm install`, `git submodule update`, project init scripts after a successful clone

## Infrastructure / containers

* [ ] add health checks and explicit `restart: unless-stopped` policies to container compose files, starting with `openwebui` (proxies to native Ollama; no retry on Ollama unavailability)
* [ ] shared base compose for the `locutus`/`hal2025` service overlap (metube, owntrack, paperless, readeck run on both; configs can drift silently without a common base)
