#!/usr/bin/env node

/**
 * Fetch all Raindrop.io tags and write them as a comma-separated,
 * alphabetically sorted list.
 *
 * Usage:
 *   RAINDROP_ACCESS_TOKEN="your_token" node raindrop-tags-fetcher.mjs
 *   node raindrop-tags-fetcher.mjs --token "your_token" --output "raindrop-tags-sorted.txt"
 *
 * Options:
 *   --token <token>             Raindrop.io API token. Can also use RAINDROP_ACCESS_TOKEN.
 *   --collection-id <id>        Raindrop collection id. Default: 0, usually all bookmarks.
 *   --output <file>             Output file. Default: raindrop-tags-sorted.txt.
 *   --case-sensitive-sort       Sort using case-sensitive locale comparison.
 *   --help                      Show help.
 */

import { writeFile } from "node:fs/promises";

const DEFAULT_CONFIG = {
    apiBaseUrl: "https://api.raindrop.io/rest/v1",
    collectionId: 0,
    outputPath: "raindrop-tags-sorted.txt",
    caseSensitiveSort: false,
};

/**
 * Print CLI help.
 *
 * @returns {void}
 */
function showHelp() {
    console.log(`
Fetch all Raindrop.io tags and write a comma-separated alphabetically sorted list.

Usage:
  RAINDROP_ACCESS_TOKEN="your_token" node raindrop-tags-fetcher.mjs
  node raindrop-tags-fetcher.mjs --token "your_token" --output "raindrop-tags-sorted.txt"

Options:
  --token <token>             Raindrop.io API token. Can also use RAINDROP_ACCESS_TOKEN.
  --collection-id <id>        Raindrop collection id. Default: 0, usually all bookmarks.
  --output <file>             Output file. Default: raindrop-tags-sorted.txt.
  --case-sensitive-sort       Sort using case-sensitive locale comparison.
  --help                      Show help.
`.trim());
}

/**
 * Parse CLI arguments.
 *
 * @param {string[]} argv
 * @returns {{
 *   apiBaseUrl: string;
 *   collectionId: number;
 *   outputPath: string;
 *   caseSensitiveSort: boolean;
 *   token: string;
 *   help?: boolean;
 * }}
 */
function parseArgs(argv) {
    const config = {
        ...DEFAULT_CONFIG,
        token: process.env.RAINDROP_ACCESS_TOKEN ?? "",
    };

    for (let index = 0; index < argv.length; index += 1) {
        const arg = argv[index];

        if (arg === "--help") {
            return { ...config, help: true };
        }

        if (arg === "--case-sensitive-sort") {
            config.caseSensitiveSort = true;
            continue;
        }

        const next = argv[index + 1];

        if (!next || next.startsWith("--")) {
            throw new Error(`Missing value for ${arg}`);
        }

        if (arg === "--token") {
            config.token = next;
        } else if (arg === "--collection-id") {
            const parsed = Number.parseInt(next, 10);

            if (!Number.isInteger(parsed)) {
                throw new Error(`Invalid --collection-id value: ${next}`);
            }

            config.collectionId = parsed;
        } else if (arg === "--output") {
            config.outputPath = next;
        } else {
            throw new Error(`Unknown option: ${arg}`);
        }

        index += 1;
    }

    return config;
}

/**
 * Convert a Raindrop tag API entry into a plain tag string.
 *
 * @param {unknown} entry
 * @returns {string | null}
 */
function normalizeTagEntry(entry) {
    if (typeof entry === "string") {
        return entry;
    }

    if (
        entry &&
        typeof entry === "object" &&
        "tag" in entry &&
        typeof entry.tag === "string"
    ) {
        return entry.tag;
    }

    if (
        entry &&
        typeof entry === "object" &&
        "_id" in entry &&
        typeof entry._id === "string"
    ) {
        return entry._id;
    }

    return null;
}

/**
 * Fetch all tags from Raindrop.io.
 *
 * @param {{
 *   apiBaseUrl: string;
 *   collectionId: number;
 *   token: string;
 *   caseSensitiveSort: boolean;
 * }} config
 * @returns {Promise<string[]>}
 */
async function fetchRaindropTags(config) {
    const url = `${config.apiBaseUrl}/tags/${encodeURIComponent(
        String(config.collectionId),
    )}`;

    const response = await fetch(url, {
        method: "GET",
        headers: {
            Authorization: `Bearer ${config.token}`,
            Accept: "application/json",
        },
    });

    const bodyText = await response.text();

    if (!response.ok) {
        throw new Error(
            `Raindrop.io API request failed: HTTP ${response.status} ${response.statusText}\n${bodyText}`,
        );
    }

    let body;

    try {
        body = JSON.parse(bodyText);
    } catch (error) {
        throw new Error(
            `Raindrop.io API returned invalid JSON: ${error instanceof Error ? error.message : String(error)
            }`,
        );
    }

    const rawTags = Array.isArray(body.items)
        ? body.items
        : Array.isArray(body.tags)
            ? body.tags
            : [];

    const tags = rawTags
        .map(normalizeTagEntry)
        .filter((tag) => typeof tag === "string" && tag.length > 0);

    if (tags.length === 0) {
        throw new Error(
            `No tags found in API response. Response keys: ${Object.keys(body).join(", ") || "(none)"
            }`,
        );
    }

    const uniqueTags = [...new Set(tags)];

    uniqueTags.sort((a, b) =>
        config.caseSensitiveSort
            ? a.localeCompare(b)
            : a.localeCompare(b, undefined, { sensitivity: "base" }),
    );

    return uniqueTags;
}

/**
 * Run the CLI.
 *
 * @returns {Promise<void>}
 */
async function main() {
    try {
        const config = parseArgs(process.argv.slice(2));

        if (config.help) {
            showHelp();
            return;
        }

        if (!config.token) {
            throw new Error(
                "Missing Raindrop.io token. Pass --token or set RAINDROP_ACCESS_TOKEN.",
            );
        }

        const tags = await fetchRaindropTags(config);
        const output = tags.join(", ");

        await writeFile(config.outputPath, output, "utf8");

        console.log(`Wrote ${tags.length} sorted tags to ${config.outputPath}`);
    } catch (error) {
        console.error(error instanceof Error ? error.message : String(error));
        process.exitCode = 1;
    }
}

await main();
