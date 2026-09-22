# Download unsplash collections

This folder contains Playwright helpers for downloading photos from Unsplash.
Both scripts share the same persistent browser profile, so signing in once
(for the Unsplash+ subscriber account, or any account) covers both.

* `download-plus-collections.ts` — downloads every collection listed on the
  Unsplash+ subscriber collections overview page. Requires a signed-in
  Unsplash+ session.
* `download-collection.ts` — downloads a single page you browse to yourself:
  a topic page (`/t/...`), a collection page (`/collections/...`), or any
  other page with a photo grid. No login is required, though signing in may
  surface more photos on some pages. It uses the page's "Download all" ZIP
  button when that actually produces a download (Unsplash shows the button
  even without Unsplash+, but clicking it opens a subscribe paywall instead
  of downloading), and otherwise falls back to downloading each photo on the
  page individually.

Both scripts open a real Chromium window. Sign in manually when asked, browse
to what you want, then return to the terminal and press Enter.

## Setup

Install the tool dependencies from this folder:

```bash
npm install
```

Install the Chromium browser used by Playwright:

```bash
npm run playwright:install
```

## Usage

### Unsplash+ collections overview

```bash
npm start
```

or explicitly:

```bash
npm run download:plus-collections
```

Useful options:

* `--collect-only` — collect collection links without downloading them.
* `--download-only` — reuse the cached queue without opening the collection
  index page.
* `--limit=NUMBER` — download at most this many collections in the current run.
* `--min-delay-ms=NUMBER` and `--max-delay-ms=NUMBER` — set the random delay
  between downloads.
* `--downloads-dir=PATH` — set where ZIP files are saved.
* `--profile-dir=PATH` — set the persistent browser profile directory.
* `--state-dir=PATH` — set where queue and cache files are saved.
* `--dry-run` — show what would download without clicking the button.
* `--verbose` — print detailed progress.
* `--quiet` — reduce output.

Downloaded collections and failures are tracked in
`state/completed.json` and `state/failed.json`, so reruns never redownload
a completed collection.

### A single topic, collection, or overview page

```bash
npm run download:collection
```

The script opens Unsplash, waits for you to browse to the page you want (for
example `/t/Fall`, or a specific collection reached from
`/@someone/collections`), and downloads it once you press Enter. Pass
`--url=URL` to start on a given page instead of the Unsplash home page — you
can still browse further before pressing Enter.

Useful options:

* `--url=URL` — navigate here first.
* `--limit=NUMBER` — download at most this many photos in the current run
  (only applies to the individual-photo fallback).
* `--min-delay-ms=NUMBER` and `--max-delay-ms=NUMBER` — set the random delay
  between individual photo downloads.
* `--downloads-dir=PATH` — set where files are saved.
* `--profile-dir=PATH` — set the persistent browser profile directory.
* `--state-dir=PATH` — set where per-collection state files are saved.
* `--dry-run` — show what would download without downloading anything.
* `--verbose` — print detailed progress.
* `--quiet` — reduce output.

Each page you download gets its own state file,
`state/collection-<slug>.json`, tracking either the ZIP download or every
individual photo ID downloaded so far. Reruns skip anything already
downloaded, which matters for open-ended pages like topics that gain new
photos over time.

## Checking the code

```bash
npm run typecheck
```

By default, local runtime data is kept under:

* `tools/unsplash-collections/browser-profile/`
* `tools/unsplash-collections/downloads/`
* `tools/unsplash-collections/state/`

All three are gitignored and stay local to the machine.
