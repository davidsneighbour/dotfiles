import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import process from "node:process";
import { createInterface } from "node:readline/promises";
import {
  type BrowserContext,
  chromium,
  type Download,
  type Page,
} from "playwright";

export type LogOptions = {
  quiet: boolean;
};

export type VerboseOptions = LogOptions & {
  verbose: boolean;
};

export function log(options: LogOptions, message: string): void {
  if (!options.quiet) {
    console.log(message);
  }
}

export function verbose(options: VerboseOptions, message: string): void {
  if (options.verbose && !options.quiet) {
    console.log(message);
  }
}

export function parsePositiveInteger(name: string, value: string): number {
  const parsed = Number.parseInt(value, 10);

  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new Error(`${name} must be a positive integer or zero.`);
  }

  return parsed;
}

export async function readJsonArray<T>(path: string): Promise<T[]> {
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

export async function readJsonObject<T>(path: string, fallback: T): Promise<T> {
  try {
    const raw = await readFile(path, "utf8");

    return JSON.parse(raw) as T;
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return fallback;
    }

    throw error;
  }
}

export async function writeJson(path: string, value: unknown): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

export function normaliseHref(href: string): string {
  return new URL(href, "https://unsplash.com").toString();
}

export function safeFilename(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-zA-Z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120)
    .toLowerCase();
}

export function pickRandomIndex(length: number): number {
  return Math.floor(Math.random() * length);
}

export function randomDelay(minDelayMs: number, maxDelayMs: number): number {
  if (minDelayMs === maxDelayMs) {
    return minDelayMs;
  }

  return minDelayMs + Math.floor(Math.random() * (maxDelayMs - minDelayMs + 1));
}

export async function waitForEnter(message: string): Promise<void> {
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

export async function launchPersistentBrowser(
  profileDir: string,
): Promise<{ context: BrowserContext; page: Page }> {
  await mkdir(profileDir, { recursive: true });

  const context = await chromium.launchPersistentContext(profileDir, {
    acceptDownloads: true,
    headless: false,
  });
  const page = context.pages()[0] ?? (await context.newPage());

  return { context, page };
}

export type DownloadAllTimeouts = {
  buttonMs: number;
  downloadMs: number;
  paywallCheckMs: number;
};

export type DownloadAllOutcome =
  | { status: "downloaded"; download: Download }
  | { status: "unavailable"; reason: "no-button" | "paywall" | "timeout" };

export async function attemptDownloadAllButton(
  page: Page,
  timeouts: DownloadAllTimeouts,
): Promise<DownloadAllOutcome> {
  const button = page.getByRole("button", { name: /^download all$/i });
  const hasButton = await button
    .waitFor({ timeout: timeouts.buttonMs })
    .then(() => true)
    .catch(() => false);

  if (!hasButton) {
    return { status: "unavailable", reason: "no-button" };
  }

  const downloadPromise = page.waitForEvent("download", {
    timeout: timeouts.downloadMs,
  });

  await button.click();

  const paywallVisible = await page
    .getByRole("dialog")
    .waitFor({ timeout: timeouts.paywallCheckMs })
    .then(() => true)
    .catch(() => false);

  if (paywallVisible) {
    await page.keyboard.press("Escape").catch(() => undefined);

    return { status: "unavailable", reason: "paywall" };
  }

  try {
    const download = await downloadPromise;

    return { status: "downloaded", download };
  } catch {
    return { status: "unavailable", reason: "timeout" };
  }
}
