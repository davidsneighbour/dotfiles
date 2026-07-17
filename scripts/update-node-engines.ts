#!/usr/bin/env -S node --experimental-strip-types

import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const CONFIG = {
  packageJsonPath: resolve(process.cwd(), "package.json"),
  scheduleUrl:
    "https://raw.githubusercontent.com/nodejs/Release/main/schedule.json",
  indentation: 2,
} as const;

type NodeScheduleEntry = {
  start: string;
  end: string;
  codename?: string;
  lts?: string | false;
  maintenance?: string;
};

type NodeSchedule = Record<string, NodeScheduleEntry>;

type PackageJson = {
  engines?: {
    node?: string;
    [key: string]: unknown;
  };
  [key: string]: unknown;
};

/**
 * Prints the CLI help text.
 *
 * @returns Nothing.
 */
function printHelp(): void {
  const command =
    "node --experimental-strip-types scripts/update-node-engines.ts";

  console.log(
    `
Usage:
  ${command} [--check] [--help]

Options:
  --check   Check whether package.json is current without writing changes.
  --help    Show this help message.

Behaviour:
  - Reads the official Node.js release schedule from:
    ${CONFIG.scheduleUrl}
  - Selects every released Node.js major whose EOL date is still in the future.
  - Includes odd-numbered majors while they are not EOL.
  - Updates package.json engines.node to an explicit semver range.
  - Example output:
    ^22.0.0 || ^24.0.0 || ^25.0.0 || ^26.0.0
`.trim(),
  );
}

/**
 * Parses CLI arguments.
 *
 * @param args - Raw CLI arguments.
 * @returns Parsed command options.
 */
function parseArgs(args: readonly string[]): { check: boolean; help: boolean } {
  const allowed = new Set(["--check", "--help"]);
  const unknown = args.filter((arg) => !allowed.has(arg));

  if (unknown.length > 0) {
    throw new Error(`Unknown option: ${unknown.join(", ")}`);
  }

  return {
    check: args.includes("--check"),
    help: args.includes("--help"),
  };
}

/**
 * Checks whether a value is a plain object.
 *
 * @param value - Value to check.
 * @returns True when the value is a plain object.
 */
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Validates and converts unknown JSON into a Node.js release schedule.
 *
 * @param value - Unknown parsed JSON value.
 * @returns Validated Node.js release schedule.
 */
function parseSchedule(value: unknown): NodeSchedule {
  if (!isRecord(value)) {
    throw new Error("Node.js release schedule must be a JSON object.");
  }

  const schedule: NodeSchedule = {};

  for (const [major, rawEntry] of Object.entries(value)) {
    if (!major.startsWith("v")) {
      continue;
    }

    if (!isRecord(rawEntry)) {
      throw new Error(`Schedule entry for ${major} must be an object.`);
    }

    const start = rawEntry["start"];
    const end = rawEntry["end"];
    const maintenance = rawEntry["maintenance"];
    const lts = rawEntry["lts"];
    const codename = rawEntry["codename"];

    if (typeof start !== "string") {
      throw new Error(
        `Schedule entry for ${major} is missing string field "start".`,
      );
    }

    if (typeof end !== "string") {
      throw new Error(
        `Schedule entry for ${major} is missing string field "end".`,
      );
    }

    schedule[major] = {
      start,
      end,
      ...(typeof codename === "string" ? { codename } : {}),
      ...(typeof maintenance === "string" ? { maintenance } : {}),
      ...(typeof lts === "string" || lts === false ? { lts } : {}),
    };
  }

  return schedule;
}

/**
 * Validates and converts unknown JSON into a package.json object.
 *
 * @param value - Unknown parsed JSON value.
 * @returns Validated package.json object.
 */
function parsePackageJson(value: unknown): PackageJson {
  if (!isRecord(value)) {
    throw new Error("package.json must contain a JSON object.");
  }

  const packageJson: PackageJson = { ...value };

  if (packageJson.engines !== undefined && !isRecord(packageJson.engines)) {
    throw new Error(
      "package.json field engines must be an object when present.",
    );
  }

  if (
    packageJson.engines !== undefined &&
    packageJson.engines.node !== undefined &&
    typeof packageJson.engines.node !== "string"
  ) {
    throw new Error(
      "package.json field engines.node must be a string when present.",
    );
  }

  return packageJson;
}

/**
 * Parses an ISO date string into a UTC timestamp at midnight.
 *
 * @param value - Date string in YYYY-MM-DD format.
 * @returns UTC timestamp.
 */
function parseDate(value: string): number {
  const timestamp = Date.parse(`${value}T00:00:00.000Z`);

  if (Number.isNaN(timestamp)) {
    throw new Error(`Invalid date in Node.js release schedule: ${value}`);
  }

  return timestamp;
}

/**
 * Returns today's date as a UTC midnight timestamp.
 *
 * @returns UTC timestamp for today's date.
 */
function getTodayUtcTimestamp(): number {
  const now = new Date();

  return Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
}

/**
 * Extracts the numeric major version from a schedule key like "v22".
 *
 * @param key - Schedule key.
 * @returns Numeric major version.
 */
function getMajorVersion(key: string): number {
  const major = Number.parseInt(key.replace(/^v/u, ""), 10);

  if (!Number.isInteger(major) || major < 1) {
    throw new Error(`Invalid Node.js major version key: ${key}`);
  }

  return major;
}

/**
 * Builds the engines.node string from the official Node.js release schedule.
 *
 * @param schedule - Validated Node.js release schedule.
 * @param todayTimestamp - UTC timestamp for the comparison date.
 * @returns Explicit engines.node semver range.
 */
function buildNodeEnginesRange(
  schedule: NodeSchedule,
  todayTimestamp: number,
): string {
  const supportedMajors = Object.entries(schedule)
    .filter(([, entry]) => {
      const startTimestamp = parseDate(entry.start);
      const endTimestamp = parseDate(entry.end);

      return startTimestamp <= todayTimestamp && endTimestamp > todayTimestamp;
    })
    .map(([major]) => getMajorVersion(major))
    .sort((left, right) => left - right);

  if (supportedMajors.length === 0) {
    throw new Error("No supported Node.js release lines found in schedule.");
  }

  return supportedMajors.map((major) => `^${major}.0.0`).join(" || ");
}

/**
 * Reads and parses JSON from a local file.
 *
 * @param filePath - JSON file path.
 * @returns Parsed JSON value.
 */
async function readJsonFile(filePath: string): Promise<unknown> {
  const content = await readFile(filePath, "utf8");

  try {
    return JSON.parse(content) as unknown;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to parse JSON file ${filePath}: ${message}`);
  }
}

/**
 * Fetches and parses JSON from a URL.
 *
 * @param url - JSON URL.
 * @returns Parsed JSON value.
 */
async function fetchJson(url: string): Promise<unknown> {
  const response = await fetch(url, {
    headers: {
      Accept: "application/json",
      "User-Agent": "node-engines-updater",
    },
  });

  if (!response.ok) {
    throw new Error(
      `Failed to fetch ${url}: ${response.status} ${response.statusText}`,
    );
  }

  try {
    return (await response.json()) as unknown;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to parse JSON response from ${url}: ${message}`);
  }
}

/**
 * Main CLI entrypoint.
 *
 * @returns Nothing.
 */
async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    printHelp();
    return;
  }

  const packageJson = parsePackageJson(
    await readJsonFile(CONFIG.packageJsonPath),
  );
  const schedule = parseSchedule(await fetchJson(CONFIG.scheduleUrl));
  const nextNodeRange = buildNodeEnginesRange(schedule, getTodayUtcTimestamp());
  const currentNodeRange = packageJson.engines?.node;

  if (currentNodeRange === nextNodeRange) {
    console.log(`engines.node is already current: ${nextNodeRange}`);
    return;
  }

  console.log(
    `Updating engines.node: ${currentNodeRange ?? "(missing)"} -> ${nextNodeRange}`,
  );

  if (options.check) {
    throw new Error("package.json engines.node is outdated.");
  }

  packageJson.engines = {
    ...(packageJson.engines ?? {}),
    node: nextNodeRange,
  };

  await writeFile(
    CONFIG.packageJsonPath,
    `${JSON.stringify(packageJson, null, CONFIG.indentation)}\n`,
    "utf8",
  );

  console.log(`Updated ${CONFIG.packageJsonPath}`);
}

try {
  await main();
} catch (error: unknown) {
  const message = error instanceof Error ? error.message : String(error);

  console.error(`update-node-engines failed: ${message}`);
  process.exitCode = 1;
}
