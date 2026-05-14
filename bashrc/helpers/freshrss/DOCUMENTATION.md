# `freshrss/` documentation

This file documents every file currently present in `bashrc/helpers/freshrss`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Files

### `freshrss/export.ts`

FreshRSS Google Reader API exporter that emits RSS XML for starred items or one label stream.

CLI option notes:

* --help — show help.
* --starred — export starred items.
* --label=NAME — export a label stream.
* --output=FILE — write RSS XML to file instead of stdout.
* --max-items=NUMBER — maximum items to fetch.
* --timeout-ms=NUMBER — HTTP timeout.

Functions/methods defined:

* `escapeXml`
* `toCdata`
* `hasText`
* `printHelp`
* `parseArgs`
* `getConfig`
* `buildStreamId`
* `buildChannelTitle`
* `fetchWithTimeout`
* `login`
* `fetchStreamPage`
* `fetchStreamItems`
* `getItemLink`
* `toRssItem`
* `buildRssXml`
* `writeOutputFile`
* `main`

Requirements:

* Node.js 24+ or newer with TypeScript execution support if run directly as .ts.
* FreshRSS mobile/API access enabled.
* Environment: FRESHRSS_BASE_URL, FRESHRSS_USERNAME, FRESHRSS_API_PASSWORD.
