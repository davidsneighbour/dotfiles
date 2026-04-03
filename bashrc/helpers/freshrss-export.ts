#!/usr/bin/env -S node

/**
 * FreshRSS stream to RSS export
 *
 * Exports either:
 * - starred items
 * - a labelled stream
 *
 * Requirements:
 * - Node.js 24+
 * - FreshRSS mobile/API access enabled
 * - User API password configured in FreshRSS
 *
 * Environment variables:
 * - FRESHRSS_BASE_URL
 * - FRESHRSS_USERNAME
 * - FRESHRSS_API_PASSWORD
 *
 * Examples:
 * - node freshrss-export.ts --starred
 * - node freshrss-export.ts --label=dnb-webdev
 * - node freshrss-export.ts --label=dnb-entertainment --output=/tmp/entertainment.xml
 */

import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import process from 'node:process';
import { randomUUID } from 'node:crypto';

type CliOptions = {
  help: boolean;
  starred: boolean;
  label: string | null;
  output: string | null;
  maxItems: number;
  timeoutMs: number;
};

type Config = {
  baseUrl: string;
  username: string;
  apiPassword: string;
  maxItems: number;
  timeoutMs: number;
};

type ClientLoginResult = {
  sid: string;
  auth: string;
};

type GoogleReaderStreamResponse = {
  id?: string;
  title?: string;
  continuation?: string;
  items?: GoogleReaderItem[];
};

type GoogleReaderItem = {
  id?: string;
  title?: string;
  canonical?: Array<{ href?: string }>;
  alternate?: Array<{ href?: string; type?: string }>;
  origin?: {
    streamId?: string;
    title?: string;
    htmlUrl?: string;
  };
  author?: string;
  published?: number;
  updated?: number;
  summary?: {
    direction?: string;
    content?: string;
  };
  content?: {
    direction?: string;
    content?: string;
  };
  enclosure?: Array<{
    href?: string;
    type?: string;
    length?: string;
  }>;
  categories?: string[];
};

type RssItem = {
  guid: string;
  title: string;
  link: string;
  pubDate: string;
  description: string;
  contentEncoded: string;
  author?: string;
  sourceTitle?: string;
};

const DEFAULTS = {
  maxItems: 250,
  timeoutMs: 20_000,
  baseUrl: 'http://192.168.1.201:3050',
} as const;

/**
 * Escapes XML special characters.
 *
 * @param value - Raw text value.
 * @returns Escaped XML-safe string.
 */
function escapeXml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

/**
 * Wraps a string in CDATA and safely splits embedded terminators.
 *
 * @param value - Raw text or HTML value.
 * @returns CDATA-safe wrapper.
 */
function toCdata(value: string): string {
  return `<![CDATA[${value.replaceAll(']]>', ']]]]><![CDATA[>')}]]>`;
}

/**
 * Returns true if the input string is a non-empty trimmed value.
 *
 * @param value - Candidate value.
 * @returns Whether the value is usable.
 */
function hasText(value: string | null | undefined): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

/**
 * Prints command help.
 */
function printHelp(): void {
  const scriptName = process.argv[1]?.split('/').pop() ?? 'freshrss-export.ts';

  console.log(`
${scriptName}

Export FreshRSS starred items or labelled items as RSS.

Usage:
  node ${scriptName} --starred [--output=FILE]
  node ${scriptName} --label=NAME [--output=FILE]

Required environment variables:
  FRESHRSS_BASE_URL
  FRESHRSS_USERNAME
  FRESHRSS_API_PASSWORD

Options:
  --help                Show this help output
  --starred             Export starred items
  --label=NAME          Export a label stream
  --output=FILE         Write RSS output to FILE instead of stdout
  --max-items=NUMBER    Maximum items to fetch (default: ${DEFAULTS.maxItems})
  --timeout-ms=NUMBER   HTTP timeout in milliseconds (default: ${DEFAULTS.timeoutMs})

Examples:
  node ${scriptName} --starred
  node ${scriptName} --label=dnb-webdev
  node ${scriptName} --label=dnb-entertainment --output=./feeds/entertainment.xml
`.trim());
}

/**
 * Parses CLI arguments.
 *
 * @param argv - Raw process arguments excluding node/script.
 * @returns Parsed options.
 */
function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = {
    help: false,
    starred: false,
    label: null,
    output: null,
    maxItems: DEFAULTS.maxItems,
    timeoutMs: DEFAULTS.timeoutMs,
  };

  for (const arg of argv) {
    if (arg === '--help') {
      options.help = true;
      continue;
    }

    if (arg === '--starred') {
      options.starred = true;
      continue;
    }

    if (arg.startsWith('--label=')) {
      const value = arg.slice('--label='.length).trim();
      if (!hasText(value)) {
        throw new Error('--label requires a non-empty value');
      }
      options.label = value;
      continue;
    }

    if (arg.startsWith('--output=')) {
      const value = arg.slice('--output='.length).trim();
      if (!hasText(value)) {
        throw new Error('--output requires a non-empty value');
      }
      options.output = value;
      continue;
    }

    if (arg.startsWith('--max-items=')) {
      const value = Number.parseInt(arg.slice('--max-items='.length), 10);
      if (!Number.isFinite(value) || value <= 0) {
        throw new Error(`Invalid --max-items value: ${arg}`);
      }
      options.maxItems = value;
      continue;
    }

    if (arg.startsWith('--timeout-ms=')) {
      const value = Number.parseInt(arg.slice('--timeout-ms='.length), 10);
      if (!Number.isFinite(value) || value <= 0) {
        throw new Error(`Invalid --timeout-ms value: ${arg}`);
      }
      options.timeoutMs = value;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  const selectedModes = Number(options.starred) + Number(options.label !== null);

  if (!options.help && selectedModes !== 1) {
    throw new Error('Choose exactly one mode: either --starred or --label=NAME');
  }

  return options;
}

/**
 * Loads and validates runtime config from environment and CLI options.
 *
 * @param options - Parsed CLI options.
 * @returns Validated config.
 */
function getConfig(options: CliOptions): Config {
  const baseUrl = process.env.FRESHRSS_BASE_URL?.trim() ?? DEFAULTS.baseUrl;
  const username = process.env.FRESHRSS_USERNAME?.trim() ?? '';
  const apiPassword = process.env.FRESHRSS_API_PASSWORD?.trim() ?? '';

  if (!hasText(username)) {
    throw new Error('Missing required environment variable: FRESHRSS_USERNAME');
  }

  if (!hasText(apiPassword)) {
    throw new Error('Missing required environment variable: FRESHRSS_API_PASSWORD');
  }

  return {
    baseUrl: baseUrl.replace(/\/+$/, ''),
    username,
    apiPassword,
    maxItems: options.maxItems,
    timeoutMs: options.timeoutMs,
  };
}

/**
 * Builds the Google Reader stream ID for the requested mode.
 *
 * @param options - Parsed CLI options.
 * @returns Stream ID string.
 */
function buildStreamId(options: CliOptions): string {
  if (options.starred) {
    return 'user/-/state/com.google/starred';
  }

  if (hasText(options.label)) {
    return `user/-/label/${options.label}`;
  }

  throw new Error('Unable to determine stream ID from CLI options');
}

/**
 * Builds a human-readable feed title.
 *
 * @param options - Parsed CLI options.
 * @returns Channel title.
 */
function buildChannelTitle(options: CliOptions): string {
  if (options.starred) {
    return 'FreshRSS Starred Items';
  }

  if (hasText(options.label)) {
    return `FreshRSS Label: ${options.label}`;
  }

  throw new Error('Unable to determine channel title from CLI options');
}

/**
 * Performs fetch with timeout.
 *
 * @param input - Request URL.
 * @param init - Fetch init.
 * @param timeoutMs - Timeout in milliseconds.
 * @returns HTTP response.
 */
async function fetchWithTimeout(input: string | URL, init: RequestInit, timeoutMs: number): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await fetch(input, {
      ...init,
      signal: controller.signal,
    });
  } catch (error: unknown) {
    if (error instanceof Error) {
      throw new Error(`Request failed: ${error.message}`);
    }
    throw new Error('Request failed with an unknown error');
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Authenticates against the FreshRSS Google Reader API.
 *
 * @param config - Runtime config.
 * @returns Session tokens.
 */
async function login(config: Config): Promise<ClientLoginResult> {
  const url = new URL(`${config.baseUrl}/api/greader.php/accounts/ClientLogin`);
  url.searchParams.set('Email', config.username);
  url.searchParams.set('Passwd', config.apiPassword);

  const response = await fetchWithTimeout(url, { method: 'GET' }, config.timeoutMs);

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`ClientLogin failed with HTTP ${response.status}: ${body}`);
  }

  const text = await response.text();
  const lines = text
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  let sid = '';
  let auth = '';

  for (const line of lines) {
    if (line.startsWith('SID=')) {
      sid = line.slice(4);
      continue;
    }

    if (line.startsWith('Auth=')) {
      auth = line.slice(5);
    }
  }

  if (!hasText(sid) || !hasText(auth)) {
    throw new Error(`Unexpected ClientLogin response:\n${text}`);
  }

  return { sid, auth };
}

/**
 * Fetches one stream page from the Google Reader API.
 *
 * @param config - Runtime config.
 * @param auth - Login auth token.
 * @param streamId - Stream ID to fetch.
 * @param maxItems - Page size.
 * @param continuation - Optional continuation token.
 * @returns Parsed stream response.
 */
async function fetchStreamPage(
  config: Config,
  auth: string,
  streamId: string,
  maxItems: number,
  continuation?: string,
): Promise<GoogleReaderStreamResponse> {
  const encodedStreamId = streamId
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');

  const url = new URL(`${config.baseUrl}/api/greader.php/reader/api/0/stream/contents/${encodedStreamId}`);
  url.searchParams.set('output', 'json');
  url.searchParams.set('n', String(maxItems));

  if (hasText(continuation)) {
    url.searchParams.set('c', continuation);
  }

  const response = await fetchWithTimeout(
    url,
    {
      method: 'GET',
      headers: {
        Authorization: `GoogleLogin auth=${auth}`,
        Accept: 'application/json',
      },
    },
    config.timeoutMs,
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Fetching stream failed with HTTP ${response.status}: ${body}`);
  }

  const json = (await response.json()) as GoogleReaderStreamResponse;
  return json;
}

/**
 * Fetches all requested stream items up to the configured limit.
 *
 * @param config - Runtime config.
 * @param auth - Login auth token.
 * @param streamId - Stream ID to fetch.
 * @returns Aggregated items.
 */
async function fetchStreamItems(
  config: Config,
  auth: string,
  streamId: string,
): Promise<GoogleReaderItem[]> {
  const collected: GoogleReaderItem[] = [];
  let continuation: string | undefined;
  const pageSize = Math.min(1000, config.maxItems);

  while (collected.length < config.maxItems) {
    const remaining = config.maxItems - collected.length;
    const page = await fetchStreamPage(
      config,
      auth,
      streamId,
      Math.min(pageSize, remaining),
      continuation,
    );

    const items = page.items ?? [];
    collected.push(...items);

    if (!hasText(page.continuation) || items.length === 0) {
      break;
    }

    continuation = page.continuation;
  }

  return collected.slice(0, config.maxItems);
}

/**
 * Returns the best available item URL.
 *
 * @param item - API item.
 * @returns Chosen URL or empty string.
 */
function getItemLink(item: GoogleReaderItem): string {
  const canonicalLink = item.canonical?.find((entry) => hasText(entry.href))?.href;
  if (hasText(canonicalLink)) {
    return canonicalLink;
  }

  const alternateLink = item.alternate?.find((entry) => hasText(entry.href))?.href;
  if (hasText(alternateLink)) {
    return alternateLink;
  }

  const originLink = item.origin?.htmlUrl;
  if (hasText(originLink)) {
    return originLink;
  }

  return '';
}

/**
 * Converts one API item into RSS item data.
 *
 * @param item - Source API item.
 * @returns RSS-ready item.
 */
function toRssItem(item: GoogleReaderItem): RssItem {
  const link = getItemLink(item);
  const title = hasText(item.title) ? item.title.trim() : (hasText(link) ? link : 'Untitled');
  const publishedEpoch = item.published ?? item.updated ?? Math.floor(Date.now() / 1000);
  const pubDate = new Date(publishedEpoch * 1000).toUTCString();
  const html = item.content?.content ?? item.summary?.content ?? '';
  const guid = hasText(item.id) ? item.id.trim() : (hasText(link) ? link : randomUUID());

  return {
    guid,
    title,
    link,
    pubDate,
    description: html,
    contentEncoded: html,
    author: hasText(item.author) ? item.author.trim() : undefined,
    sourceTitle: hasText(item.origin?.title) ? item.origin.title.trim() : undefined,
  };
}

/**
 * Builds RSS XML output.
 *
 * @param config - Runtime config.
 * @param channelTitle - Channel title.
 * @param items - Stream items.
 * @returns RSS 2.0 XML string.
 */
function buildRssXml(config: Config, channelTitle: string, items: GoogleReaderItem[]): string {
  const rssItems = items.map(toRssItem);
  const channelLink = `${config.baseUrl}/`;
  const channelDescription = `${channelTitle} for FreshRSS user ${config.username}`;
  const lastBuildDate = new Date().toUTCString();

  const itemXml = rssItems
    .map((item) => {
      const linkXml = hasText(item.link)
        ? `<link>${escapeXml(item.link)}</link>`
        : '';

      const authorXml = hasText(item.author)
        ? `<author>${escapeXml(item.author)}</author>`
        : '';

      const sourceXml = hasText(item.sourceTitle) && hasText(item.link)
        ? `<source url="${escapeXml(item.link)}">${escapeXml(item.sourceTitle)}</source>`
        : '';

      return [
        '<item>',
        `<title>${escapeXml(item.title)}</title>`,
        linkXml,
        `<guid isPermaLink="false">${escapeXml(item.guid)}</guid>`,
        `<pubDate>${escapeXml(item.pubDate)}</pubDate>`,
        `<description>${toCdata(item.description)}</description>`,
        `<content:encoded>${toCdata(item.contentEncoded)}</content:encoded>`,
        authorXml,
        sourceXml,
        '</item>',
      ]
        .filter((part) => part.length > 0)
        .join('');
    })
    .join('');

  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">',
    '<channel>',
    `<title>${escapeXml(channelTitle)}</title>`,
    `<link>${escapeXml(channelLink)}</link>`,
    `<description>${escapeXml(channelDescription)}</description>`,
    `<lastBuildDate>${escapeXml(lastBuildDate)}</lastBuildDate>`,
    '<generator>FreshRSS export CLI</generator>',
    itemXml,
    '</channel>',
    '</rss>',
  ].join('');
}

/**
 * Writes output to a file, creating parent directories if required.
 *
 * @param outputPath - Destination path.
 * @param content - File content.
 */
async function writeOutputFile(outputPath: string, content: string): Promise<void> {
  const absolutePath = resolve(outputPath);
  await mkdir(dirname(absolutePath), { recursive: true });
  await writeFile(absolutePath, content, 'utf8');
}

/**
 * Main program entry point.
 */
async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    printHelp();
    return;
  }

  const config = getConfig(options);
  const streamId = buildStreamId(options);
  const channelTitle = buildChannelTitle(options);

  const session = await login(config);
  const items = await fetchStreamItems(config, session.auth, streamId);
  const xml = buildRssXml(config, channelTitle, items);

  if (hasText(options.output)) {
    await writeOutputFile(options.output, `${xml}\n`);
    console.error(`Wrote feed to ${resolve(options.output)}`);
    return;
  }

  process.stdout.write(`${xml}\n`);
}

main().catch((error: unknown) => {
  if (error instanceof Error) {
    console.error(`ERROR: ${error.message}`);
  } else {
    console.error('ERROR: Unknown error');
  }

  process.exitCode = 1;
});
