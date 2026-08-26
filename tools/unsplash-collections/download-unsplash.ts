#!/usr/bin/env -S node --experimental-strip-types

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { basename, dirname, extname, resolve } from "node:path";
import process from "node:process";
import { createInterface } from "node:readline/promises";
import { fileURLToPath } from "node:url";
import { chromium, type Page } from "playwright";

const COLLECTIONS_URL = "https://unsplash.com/@unsplashplus/collections";
const TOOL_DIR = dirname(fileURLToPath(import.meta.url));

type CollectionItem = {
  href: string;
  title: string;
  description: string;
};

type CompletedItem = CollectionItem & {
  downloadedAt: string;
  filename: string;
};

type FailedItem = CollectionItem & {
  failedAt: string;
  message: string;
};

type CliOptions = {
  collectOnly: boolean;
  downloadOnly: boolean;
  downloadsDir: string;
  dryRun: boolean;
  expectedCount: number;
  help: boolean;
  limit: number | null;
  maxDelayMs: number;
  minDelayMs: number;
  profileDir: string;
  quiet: boolean;
  stateDir: string;
  verbose: boolean;
};

type StatePaths = {
  cache: string;
  completed: string;
  failed: string;
  queue: string;
};

function printHelp(): void {
  console.log(
    `
Usage:
  npm start -- [options]
  node --experimental-strip-types download-unsplash.ts [options]

Options:
  --collect-only          Collect links and update the queue without downloads.
  --download-only         Skip collection page collection and use the queue.
  --limit=NUMBER         Download at most NUMBER collections in this run.
  --downloads-dir=PATH   Directory for ZIP files.
  --profile-dir=PATH     Persistent Playwright browser profile directory.
  --state-dir=PATH       Directory for queue and cache JSON files.
  --expected-count=NUM   Warn when fewer than NUM collections are found.
  --min-delay-ms=NUM     Minimum random delay between downloads.
  --max-delay-ms=NUM     Maximum random delay between downloads.
  --dry-run              Do not click Download all.
  --verbose              Print detailed progress.
  --quiet                Print only important messages.
  --help                 Show this help.
`.trim(),
  );
}

function parsePositiveInteger(name: string, value: string): number {
  const parsed = Number.parseInt(value, 10);

  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new Error(`${name} must be a positive integer or zero.`);
  }

  return parsed;
}

function parseArgs(args: readonly string[]): CliOptions {
  const options: CliOptions = {
    collectOnly: false,
    downloadOnly: false,
    downloadsDir: resolve(TOOL_DIR, "downloads"),
    dryRun: false,
    expectedCount: 325,
    help: false,
    limit: null,
    maxDelayMs: 15_000,
    minDelayMs: 1_000,
    profileDir: resolve(TOOL_DIR, "browser-profile"),
    quiet: false,
    stateDir: resolve(TOOL_DIR, "state"),
    verbose: process.env["DNB_VERBOSE"] === "1",
  };

  for (const arg of args) {
    if (arg === "--collect-only") {
      options.collectOnly = true;
    } else if (arg === "--download-only") {
      options.downloadOnly = true;
    } else if (arg === "--dry-run") {
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
    } else if (arg.startsWith("--expected-count=")) {
      options.expectedCount = parsePositiveInteger(
        "--expected-count",
        arg.slice("--expected-count=".length),
      );
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
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  if (options.collectOnly && options.downloadOnly) {
    throw new Error(
      "--collect-only and --download-only cannot be used together.",
    );
  }

  if (options.minDelayMs > options.maxDelayMs) {
    throw new Error(
      "--min-delay-ms must be less than or equal to --max-delay-ms.",
    );
  }

  return options;
}

function log(options: CliOptions, message: string): void {
  if (!options.quiet) {
    console.log(message);
  }
}

function verbose(options: CliOptions, message: string): void {
  if (options.verbose && !options.quiet) {
    console.log(message);
  }
}

function createStatePaths(stateDir: string): StatePaths {
  return {
    cache: resolve(stateDir, "collections-cache.json"),
    completed: resolve(stateDir, "completed.json"),
    failed: resolve(stateDir, "failed.json"),
    queue: resolve(stateDir, "queue.json"),
  };
}

async function readJsonArray<T>(path: string): Promise<T[]> {
  try {
    const raw = await readFile(path, "utf8");
    const parsed: unknown = JSON.parse(raw);

    if (!Array.isArray(parsed)) {
      throw new Error(`${path} must contain a JSON array.`);
    }

    return parsed as T[];
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return [];
    }

    throw error;
  }
}

async function writeJson(path: string, value: unknown): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function normaliseHref(href: string): string {
  return new URL(href, "https://unsplash.com").toString();
}

function uniqueItems(items: readonly CollectionItem[]): CollectionItem[] {
  const byHref = new Map<string, CollectionItem>();

  for (const item of items) {
    byHref.set(item.href, item);
  }

  return [...byHref.values()].sort((left, right) =>
    left.title.localeCompare(right.title),
  );
}

function removeCompleted(
  items: readonly CollectionItem[],
  completed: readonly CompletedItem[],
): CollectionItem[] {
  const completedHrefs = new Set(completed.map((item) => item.href));

  return items.filter((item) => !completedHrefs.has(item.href));
}

function pickRandomIndex(length: number): number {
  return Math.floor(Math.random() * length);
}

function randomDelay(minDelayMs: number, maxDelayMs: number): number {
  if (minDelayMs === maxDelayMs) {
    return minDelayMs;
  }

  return minDelayMs + Math.floor(Math.random() * (maxDelayMs - minDelayMs + 1));
}

async function waitForEnter(message: string): Promise<void> {
  const readline = createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  try {
    await readline.question(message);
  } finally {
    readline.close();
  }
}

async function collectCollections(
  page: Page,
  options: CliOptions,
): Promise<CollectionItem[]> {
  await page.goto(COLLECTIONS_URL, { waitUntil: "domcontentloaded" });

  await waitForEnter(
    [
      "Sign in if Unsplash asks for it, then scroll the collections page to the end.",
      "When all collection cards are visible, press Enter here to collect links.",
      "",
    ].join("\n"),
  );

  await page.waitForSelector('[data-testid="collection-feed-card"]', {
    timeout: 120_000,
  });

  const rawItems = await page.$$eval(
    '[data-testid="collection-feed-card"]',
    (cards) =>
      cards.flatMap((card) => {
        const anchor = card.querySelector('a[href^="/collections/"]');
        const href = anchor?.getAttribute("href");
        const title = card
          .querySelector('[class*="title-"]')
          ?.textContent?.trim();
        const description =
          card.querySelector('[class*="description-"]')?.textContent?.trim() ??
          "";

        if (!href || !title) {
          return [];
        }

        return [
          {
            description,
            href,
            title,
          },
        ];
      }),
  );

  const items = uniqueItems(
    rawItems.map((item) => ({
      description: item.description,
      href: normaliseHref(item.href),
      title: item.title,
    })),
  );

  if (items.length < options.expectedCount) {
    log(
      options,
      `Warning: collected ${items.length} collections, expected about ${options.expectedCount}.`,
    );
  } else {
    log(options, `Collected ${items.length} collections.`);
  }

  return items;
}

function safeFilename(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-zA-Z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120)
    .toLowerCase();
}

function createDownloadPath(
  downloadsDir: string,
  item: CollectionItem,
  suggested: string,
): string {
  const extension = extname(suggested) || ".zip";
  const suggestedBase = basename(suggested, extname(suggested));
  const base =
    safeFilename(`${item.title}-${suggestedBase}`) || "unsplash-collection";

  return resolve(downloadsDir, `${base}${extension}`);
}

async function downloadCollection(
  page: Page,
  item: CollectionItem,
  options: CliOptions,
): Promise<CompletedItem> {
  log(options, `Downloading: ${item.title}`);
  verbose(options, item.href);

  if (options.dryRun) {
    return {
      ...item,
      downloadedAt: new Date().toISOString(),
      filename: "dry-run",
    };
  }

  await page.goto(item.href, { waitUntil: "domcontentloaded" });

  const button = page.getByRole("button", { name: /^download all$/i });
  await button.waitFor({ timeout: 120_000 });

  const downloadPromise = page.waitForEvent("download", { timeout: 300_000 });
  await button.click();
  const download = await downloadPromise;
  const filename = createDownloadPath(
    options.downloadsDir,
    item,
    download.suggestedFilename(),
  );

  await download.saveAs(filename);

  return {
    ...item,
    downloadedAt: new Date().toISOString(),
    filename,
  };
}

async function runDownloads(
  page: Page,
  paths: StatePaths,
  options: CliOptions,
): Promise<void> {
  await mkdir(options.downloadsDir, { recursive: true });

  const completed = await readJsonArray<CompletedItem>(paths.completed);
  const failed = await readJsonArray<FailedItem>(paths.failed);
  const queue = await readJsonArray<CollectionItem>(paths.queue);
  const runLimit = options.limit ?? queue.length;
  let remaining = [...queue];
  const failedThisRun = new Set<string>();
  let successCount = 0;

  while (remaining.length > 0 && successCount < runLimit) {
    const candidates = remaining.filter(
      (item) => !failedThisRun.has(item.href),
    );

    if (candidates.length === 0) {
      log(options, "All remaining queued collections failed in this run.");
      break;
    }

    const index = pickRandomIndex(candidates.length);
    const item = candidates[index];

    if (item === undefined) {
      throw new Error("Failed to pick a queued collection.");
    }

    try {
      const completedItem = await downloadCollection(page, item, options);
      remaining = remaining.filter(
        (queuedItem) => queuedItem.href !== item.href,
      );
      successCount += 1;

      if (options.dryRun) {
        log(options, `Would download: ${completedItem.title}`);
      } else {
        completed.push(completedItem);
        await writeJson(paths.completed, completed);
        await writeJson(paths.queue, remaining);
        log(options, `Saved: ${completedItem.filename}`);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      failed.push({
        ...item,
        failedAt: new Date().toISOString(),
        message,
      });
      await writeJson(paths.failed, failed);
      failedThisRun.add(item.href);
      log(options, `Failed: ${item.title}: ${message}`);
    }

    if (remaining.length > 0 && successCount < runLimit) {
      const delay = randomDelay(options.minDelayMs, options.maxDelayMs);
      verbose(options, `Waiting ${delay} ms before the next download.`);
      await page.waitForTimeout(delay);
    }
  }

  log(
    options,
    options.dryRun
      ? `Dry run complete. Checked ${successCount}. Persistent queue was not changed.`
      : `Run complete. Downloaded ${successCount}. Remaining queue: ${remaining.length}.`,
  );
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    printHelp();
    return;
  }

  await mkdir(options.profileDir, { recursive: true });
  await mkdir(options.stateDir, { recursive: true });

  const paths = createStatePaths(options.stateDir);
  const context = await chromium.launchPersistentContext(options.profileDir, {
    acceptDownloads: true,
    headless: false,
  });
  const page = context.pages()[0] ?? (await context.newPage());

  try {
    if (!options.downloadOnly) {
      const completed = await readJsonArray<CompletedItem>(paths.completed);
      const collections = await collectCollections(page, options);
      const queue = removeCompleted(collections, completed);

      await writeJson(paths.cache, collections);
      await writeJson(paths.queue, queue);
      log(options, `Queue contains ${queue.length} collections.`);
    }

    if (!options.collectOnly) {
      await runDownloads(page, paths, options);
    }
  } finally {
    await context.close();
  }
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`download-unsplash failed: ${message}`);
  process.exitCode = 1;
});
