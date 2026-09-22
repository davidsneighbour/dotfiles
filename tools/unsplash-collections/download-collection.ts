#!/usr/bin/env -S node --experimental-strip-types

import { mkdir } from "node:fs/promises";
import { dirname, extname, resolve } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import type { Page } from "playwright";
import {
  attemptDownloadAllButton,
  launchPersistentBrowser,
  log,
  normaliseHref,
  parsePositiveInteger,
  randomDelay,
  readJsonObject,
  safeFilename,
  verbose,
  waitForEnter,
  writeJson,
} from "./lib.ts";

const START_URL = "https://unsplash.com/";
const FIGURE_SELECTOR = '[data-testid="asset-grid-masonry-figure"]';
const TOOL_DIR = dirname(fileURLToPath(import.meta.url));

type PhotoRecord = {
  downloadedAt: string;
  filename: string;
  id: string;
  href: string;
};

type CollectionState = {
  mode: "individual" | "zip" | null;
  photos: PhotoRecord[];
  title: string;
  updatedAt: string;
  url: string;
  zip: { downloadedAt: string; filename: string } | null;
};

type PhotoLink = {
  downloadHref: string;
  id: string;
};

type CliOptions = {
  downloadsDir: string;
  dryRun: boolean;
  help: boolean;
  limit: number | null;
  maxDelayMs: number;
  minDelayMs: number;
  profileDir: string;
  quiet: boolean;
  stateDir: string;
  url: string | null;
  verbose: boolean;
};

function printHelp(): void {
  console.log(
    `
Usage:
  npm run download:collection -- [options]
  node --experimental-strip-types download-collection.ts [options]

Opens Unsplash and waits for you to browse to a topic page (/t/...), a
collection page (/collections/...), or a user's collections overview, then
press Enter. It downloads that page's Download all ZIP when it is genuinely
available, otherwise it downloads every photo on the page individually.

Options:
  --url=URL              Navigate here first; you can still browse further before Enter.
  --limit=NUMBER         Download at most NUMBER photos in this run.
  --downloads-dir=PATH   Directory for downloaded files.
  --profile-dir=PATH     Persistent Playwright browser profile directory.
  --state-dir=PATH       Directory for per-collection state JSON files.
  --min-delay-ms=NUM     Minimum random delay between individual photo downloads.
  --max-delay-ms=NUM     Maximum random delay between individual photo downloads.
  --dry-run              Do not download anything.
  --verbose              Print detailed progress.
  --quiet                Print only important messages.
  --help                 Show this help.
`.trim(),
  );
}

function parseArgs(args: readonly string[]): CliOptions {
  const options: CliOptions = {
    downloadsDir: resolve(TOOL_DIR, "downloads"),
    dryRun: false,
    help: false,
    limit: null,
    maxDelayMs: 8_000,
    minDelayMs: 1_000,
    profileDir: resolve(TOOL_DIR, "browser-profile"),
    quiet: false,
    stateDir: resolve(TOOL_DIR, "state"),
    url: null,
    verbose: process.env["DNB_VERBOSE"] === "1",
  };

  for (const arg of args) {
    if (arg === "--dry-run") {
      options.dryRun = true;
    } else if (arg === "--help") {
      options.help = true;
    } else if (arg === "--quiet") {
      options.quiet = true;
      options.verbose = false;
      delete process.env["DNB_VERBOSE"];
    } else if (arg === "--verbose") {
      options.verbose = true;
      process.env["DNB_VERBOSE"] = "1";
    } else if (arg.startsWith("--downloads-dir=")) {
      options.downloadsDir = resolve(arg.slice("--downloads-dir=".length));
    } else if (arg.startsWith("--limit=")) {
      options.limit = parsePositiveInteger(
        "--limit",
        arg.slice("--limit=".length),
      );
    } else if (arg.startsWith("--max-delay-ms=")) {
      options.maxDelayMs = parsePositiveInteger(
        "--max-delay-ms",
        arg.slice("--max-delay-ms=".length),
      );
    } else if (arg.startsWith("--min-delay-ms=")) {
      options.minDelayMs = parsePositiveInteger(
        "--min-delay-ms",
        arg.slice("--min-delay-ms=".length),
      );
    } else if (arg.startsWith("--profile-dir=")) {
      options.profileDir = resolve(arg.slice("--profile-dir=".length));
    } else if (arg.startsWith("--state-dir=")) {
      options.stateDir = resolve(arg.slice("--state-dir=".length));
    } else if (arg.startsWith("--url=")) {
      options.url = arg.slice("--url=".length);
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  if (options.minDelayMs > options.maxDelayMs) {
    throw new Error(
      "--min-delay-ms must be less than or equal to --max-delay-ms.",
    );
  }

  return options;
}

function slugForUrl(url: string): string {
  const pathname = new URL(url).pathname;
  const slug = safeFilename(pathname.split("/").filter(Boolean).join("-"));

  return slug || "collection";
}

async function loadAllPhotoFigures(page: Page): Promise<void> {
  let previousCount = -1;
  let idleRounds = 0;

  for (let round = 0; round < 200; round += 1) {
    const loadMoreButton = page.getByRole("button", { name: /^load more$/i });
    const hasLoadMore = await loadMoreButton.isVisible().catch(() => false);

    if (hasLoadMore) {
      await loadMoreButton.click().catch(() => undefined);
    } else {
      await page.evaluate(() => {
        window.scrollTo(0, document.body.scrollHeight);
      });
    }

    await page.waitForTimeout(900);

    const count = await page.locator(FIGURE_SELECTOR).count();

    if (count === previousCount) {
      idleRounds += 1;

      if (idleRounds >= 3) {
        break;
      }
    } else {
      idleRounds = 0;
    }

    previousCount = count;
  }
}

async function collectPhotoLinks(page: Page): Promise<PhotoLink[]> {
  const rawHrefs = await page.$$eval(
    `${FIGURE_SELECTOR} a[aria-label="Download"]`,
    (anchors) =>
      anchors
        .map((anchor) => anchor.getAttribute("href"))
        .filter((href): href is string => Boolean(href)),
  );

  const byId = new Map<string, string>();

  for (const href of rawHrefs) {
    const match = /\/photos\/([A-Za-z0-9_-]+)\/download/.exec(href);
    const id = match?.[1];

    if (id) {
      byId.set(id, normaliseHref(href));
    }
  }

  return [...byId.entries()].map(([id, downloadHref]) => ({
    downloadHref,
    id,
  }));
}

async function downloadPhoto(
  downloadPage: Page,
  link: PhotoLink,
  downloadsDir: string,
): Promise<PhotoRecord> {
  const downloadPromise = downloadPage.waitForEvent("download", {
    timeout: 60_000,
  });

  await downloadPage
    .goto(link.downloadHref, { waitUntil: "commit" })
    .catch(() => undefined);

  const download = await downloadPromise;
  const extension = extname(download.suggestedFilename()) || ".jpg";
  const filename = resolve(downloadsDir, `${link.id}${extension}`);

  await download.saveAs(filename);

  return {
    downloadedAt: new Date().toISOString(),
    filename,
    href: link.downloadHref,
    id: link.id,
  };
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    printHelp();
    return;
  }

  await mkdir(options.stateDir, { recursive: true });
  await mkdir(options.downloadsDir, { recursive: true });

  const { context, page } = await launchPersistentBrowser(options.profileDir);

  try {
    await page.goto(options.url ?? START_URL, {
      waitUntil: "domcontentloaded",
    });

    await waitForEnter(
      [
        "Browse to the topic, collection, or collections overview page you want.",
        "Sign in if you want a logged-in session (optional, no login is required).",
        "When you are on the page you want to download, press Enter here.",
        "",
      ].join("\n"),
    );

    const currentUrl = normaliseHref(page.url());
    const slug = slugForUrl(currentUrl);
    const statePath = resolve(options.stateDir, `collection-${slug}.json`);

    const state = await readJsonObject<CollectionState>(statePath, {
      mode: null,
      photos: [],
      title: "",
      updatedAt: new Date().toISOString(),
      url: currentUrl,
      zip: null,
    });

    const title =
      (
        await page
          .locator("h1")
          .first()
          .textContent()
          .catch(() => null)
      )?.trim() ||
      state.title ||
      slug;

    log(options, `Collection: ${title}`);
    verbose(options, currentUrl);

    if (state.zip) {
      log(options, `Already downloaded as a ZIP: ${state.zip.filename}`);
      return;
    }

    if (!options.dryRun) {
      const outcome = await attemptDownloadAllButton(page, {
        buttonMs: 6_000,
        downloadMs: 180_000,
        paywallCheckMs: 3_000,
      });

      if (outcome.status === "downloaded") {
        const extension =
          extname(outcome.download.suggestedFilename()) || ".zip";
        const filename = resolve(
          options.downloadsDir,
          `${slug}-${safeFilename(title) || "collection"}${extension}`,
        );

        await outcome.download.saveAs(filename);

        await writeJson(statePath, {
          ...state,
          mode: "zip",
          title,
          updatedAt: new Date().toISOString(),
          url: currentUrl,
          zip: { downloadedAt: new Date().toISOString(), filename },
        } satisfies CollectionState);

        log(options, `Saved ZIP: ${filename}`);
        return;
      }

      verbose(
        options,
        `Download all was not available (${outcome.reason}); downloading photos individually.`,
      );
    }

    await loadAllPhotoFigures(page);
    const links = await collectPhotoLinks(page);

    log(options, `Found ${links.length} downloadable photo(s) on this page.`);

    const alreadyDownloaded = new Set(state.photos.map((photo) => photo.id));
    const pending = links.filter((link) => !alreadyDownloaded.has(link.id));
    const runLimit = options.limit ?? pending.length;

    if (pending.length === 0) {
      log(options, "Nothing new to download.");
      return;
    }

    const photos = [...state.photos];
    let successCount = 0;
    const downloadPage = await context.newPage();

    try {
      for (const link of pending) {
        if (successCount >= runLimit) {
          break;
        }

        if (options.dryRun) {
          log(options, `Would download: ${link.id}`);
          successCount += 1;
          continue;
        }

        try {
          const record = await downloadPhoto(
            downloadPage,
            link,
            options.downloadsDir,
          );

          photos.push(record);
          successCount += 1;

          await writeJson(statePath, {
            ...state,
            mode: "individual",
            photos,
            title,
            updatedAt: new Date().toISOString(),
            url: currentUrl,
          } satisfies CollectionState);

          log(options, `Saved: ${record.filename}`);
        } catch (error) {
          const message =
            error instanceof Error ? error.message : String(error);
          log(options, `Failed: ${link.id}: ${message}`);
        }

        if (successCount < runLimit) {
          const delay = randomDelay(options.minDelayMs, options.maxDelayMs);
          verbose(options, `Waiting ${delay} ms before the next download.`);
          await downloadPage.waitForTimeout(delay);
        }
      }
    } finally {
      await downloadPage.close();
    }

    log(
      options,
      options.dryRun
        ? `Dry run complete. ${pending.length} photo(s) pending.`
        : `Run complete. Downloaded ${successCount} new photo(s). ${photos.length} total tracked for this collection.`,
    );
  } finally {
    await context.close();
  }
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`download-collection failed: ${message}`);
  process.exitCode = 1;
});
