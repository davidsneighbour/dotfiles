# Download unsplash+ collections

This folder contains a Playwright helper for downloading the Unsplash+
collection ZIP files that are available to the signed-in subscriber account.

The script opens a real Chromium window because Unsplash requires a logged-in
session. Sign in manually when needed, scroll the collections page to the end,
then return to the terminal and press Enter.

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

Run the downloader from this folder:

```bash
npm start
```

Check the downloader:

```bash
npm run typecheck
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

By default, local runtime data is kept under:

* `tools/unsplash-collections/browser-profile/`
* `tools/unsplash-collections/downloads/`
* `tools/unsplash-collections/state/`

These paths are gitignored.
