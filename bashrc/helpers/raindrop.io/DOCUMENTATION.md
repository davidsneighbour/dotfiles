# `raindrop.io/` documentation

This file documents every file currently present in `bashrc/helpers/raindrop.io`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Files

### `raindrop.io/getTags.ts`

Fetches and prints tags for a Raindrop.io collection.

CLI option notes:

* --token TOKEN — Raindrop access token; default RAINDROP_ACCESS_TOKEN.
* --collection-id ID — collection ID.
* --output PATH — file to write tags.
* --case-sensitive-sort — do not lowercase for sorting.
* --help — show help.

Functions/methods defined:

* `isRecord`
* `showHelp`
* `parseArgs`
* `normalizeTagEntry`
* `fetchRaindropTags`
* `main`

Requirements:

* Node.js with TypeScript execution support.
* Environment/API token required by script options (see options).
* Network access to Raindrop.io API.
