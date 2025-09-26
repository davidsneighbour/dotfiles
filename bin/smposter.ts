#!/usr/bin/env -S node --experimental-strip-types

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import readline from 'node:readline';
import {
  Client,
  // TwitterStrategy,
  MastodonStrategy,
  BlueskyStrategy,
  // LinkedInStrategy,
  // DiscordStrategy,
  // DiscordWebhookStrategy,
  // TelegramStrategy,
  // DevtoStrategy,
} from '@humanwhocodes/crosspost';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

type CliOptions = {
  help: boolean;
  version: boolean;
  verbose: boolean;
  args: string[];
};

// ---- Strict, safe .env parsing + loading ----

/**
 * Parse a .env file into key/value pairs.
 * - Supports KEY=VALUE
 * - Respects quoted values ('...' or "...")
 * - Strips inline comments for unquoted values
 * - Returns only string values
 */
function parseDotEnv(content: string): Record<string, string> {
  const out: Record<string, string> = {};
  const lines = content.split(/\r?\n/);

  for (const raw of lines) {
    const line = raw.trim();
    if (line === '' || line.startsWith('#')) continue;

    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!match) continue;

    // match[1] and match[2] are present due to regex; bind them to typed locals
    const key: string = match[1];
    let val: string = match[2];

    const quoted =
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"));

    if (!quoted) {
      // strip inline comment for unquoted values
      const hashIdx = val.indexOf('#');
      if (hashIdx !== -1) val = val.slice(0, hashIdx).trim();
      val = val.trim();
    } else {
      // remove surrounding quotes
      const quote = val[0];
      val = val.slice(1, -1);
      if (quote === '"') {
        // unescape common sequences for double-quoted values
        val = val
          .replace(/\\n/g, '\n')
          .replace(/\\r/g, '\r')
          .replace(/\\t/g, '\t')
          .replace(/\\"/g, '"')
          .replace(/\\\\/g, '\\');
      }
      // single quotes are treated as literals
    }

    // Only assign concrete strings
    out[key] = val;
  }

  return out;
}

/**
 * Load env from ~/.env then ./.env (cwd overrides).
 */
function loadEnv(): void {
  const home = process.env['HOME'] || process.env['USERPROFILE'] || '';
  const homeEnvPath = home ? path.join(home, '.env') : '';
  const cwdEnvPath = path.join(process.cwd(), '.env');

  const sources: string[] = [];
  if (homeEnvPath && fs.existsSync(homeEnvPath)) sources.push(homeEnvPath);
  if (fs.existsSync(cwdEnvPath)) sources.push(cwdEnvPath);

  for (const p of sources) {
    try {
      const parsed = parseDotEnv(fs.readFileSync(p, 'utf8'));
      for (const [k, v] of Object.entries(parsed)) {
        // assign only strings; v is string by construction
        process.env[k] = v;
      }
    } catch {
      // ignore unreadable files
    }
  }
}

/** Get an env var or undefined (typed), using bracket access. */
function getEnv(name: string): string | undefined {
  const v = process.env[name];
  return typeof v === 'string' && v.length > 0 ? v : undefined;
}

function hasGum(): boolean {
  const res = spawnSync('bash', ['-lc', 'command -v gum'], { stdio: 'pipe', encoding: 'utf8' });
  return res.status === 0 && (res.stdout ?? '').trim().length > 0;
}

async function promptText(maxLen: number, verbose: boolean): Promise<string> {
  if (hasGum()) {
    for (;;) {
      spawnSync('gum', ['style', '--border', 'rounded', '--padding', '1', '--margin', '1', `Enter text (max ${maxLen} chars).`], {
        stdio: ['ignore', 'inherit', 'inherit'],
      });
      const p = spawnSync('gum', ['write', '--width', '80', '--placeholder', 'Type here...'], {
        stdio: ['inherit', 'pipe', 'inherit'],
        encoding: 'utf8',
      });
      if (p.status === 0) {
        const text = (p.stdout ?? '').replace(/\r/g, '');
        if (text.length <= maxLen) return text;
        spawnSync('gum', ['confirm', `Text is ${text.length} chars, exceeds ${maxLen}. Try again?`], { stdio: 'inherit' });
        continue;
      }
      break;
    }
  }
  if (verbose) console.error('[smposter] gum not available, using stdin');
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const ask = (q: string) => new Promise<string>((resolve) => rl.question(q, resolve));
  let out = '';
  for (;;) {
    out = await ask(`Enter text (max ${maxLen} chars): `);
    if (out.length <= maxLen) break;
    console.error(`Input is ${out.length} chars, exceeds ${maxLen}. Please shorten.`);
  }
  rl.close();
  return out;
}

function parseArgs(argv: readonly string[]): CliOptions {
  const opts: CliOptions = { help: false, version: false, verbose: false, args: [] };
  for (let i = 2; i < argv.length; i++) {
    const v = argv[i];
    if (v === '-h' || v === '--help') opts.help = true;
    else if (v === '-v' || v === '--version') opts.version = true;
    else if (v === '--verbose') opts.verbose = true;
    else opts.args.push(v);
  }
  return opts;
}

function printHelp(): void {
  console.log(`Usage:
  smposter [options]

Options:
  -h, --help        Show help and exit
  -v, --version     Show version and exit
      --verbose     Verbose logging

Description:
  Loads env from ~/.env then ./.env (cwd overrides).
  Prompts for a text snippet (max 500 chars) and posts to configured services
  using @humanwhocodes/crosspost.
`);
}

function getVersion(): string {
  return '1.2.0';
}

/* ---------- Crosspost integration ---------- */

function buildStrategies(verbose: boolean) {
  const strategies: Array<
    | ReturnType<typeof BlueskyStrategy>
    | ReturnType<typeof MastodonStrategy>
    // | ReturnType<typeof TwitterStrategy>
    // | ReturnType<typeof LinkedInStrategy>
    // | ReturnType<typeof DiscordStrategy>
    // | ReturnType<typeof DiscordWebhookStrategy>
    // | ReturnType<typeof TelegramStrategy>
    // | ReturnType<typeof DevtoStrategy>
  > = [];

  try {
    strategies.push(
      new BlueskyStrategy({
        identifier: process.env['BLUESKY_IDENTIFIER']!,
        password: process.env['BLUESKY_PASSWORD']!,
        host: process.env['BLUESKY_HOST']!,
      }),
    );
  } catch (e) {
    if (verbose) console.error('[smposter] BlueskyStrategy skipped:', (e as Error).message);
  }

  try {
    strategies.push(
      new MastodonStrategy({
        accessToken: process.env['MASTODON_ACCESS_TOKEN']!,
        host: process.env['MASTODON_HOST']!,
      }),
    );
  } catch (e) {
    if (verbose) console.error('[smposter] MastodonStrategy skipped:', (e as Error).message);
  }

  // try {
  //   strategies.push(
  //     new TwitterStrategy({
  //       accessTokenKey: 'access-token-key',
  //       accessTokenSecret: 'access-token-secret',
  //       apiConsumerKey: 'api-consumer-key',
  //       apiConsumerSecret: 'api-consumer-secret',
  //     }),
  //   );
  // } catch (e) {
  //   if (verbose) console.error('[smposter] TwitterStrategy skipped:', (e as Error).message);
  // }

  // try {
  //   strategies.push(
  //     new LinkedInStrategy({
  //       accessToken: 'your-access-token',
  //     }),
  //   );
  // } catch (e) {
  //   if (verbose) console.error('[smposter] LinkedInStrategy skipped:', (e as Error).message);
  // }

  // try {
  //   strategies.push(
  //     new DiscordStrategy({
  //       botToken: 'your-bot-token',
  //       channelId: 'your-channel-id',
  //     }),
  //   );
  // } catch (e) {
  //   if (verbose) console.error('[smposter] DiscordStrategy skipped:', (e as Error).message);
  // }

  // try {
  //   strategies.push(
  //     new DiscordWebhookStrategy({
  //       webhookUrl: 'your-webhook-url',
  //     }),
  //   );
  // } catch (e) {
  //   if (verbose) console.error('[smposter] DiscordWebhookStrategy skipped:', (e as Error).message);
  // }

  // try {
  //   strategies.push(
  //     new TelegramStrategy({
  //       botToken: 'your-bot-token',
  //       chatId: 'your-chat-id',
  //     }),
  //   );
  // } catch (e) {
  //   if (verbose) console.error('[smposter] TelegramStrategy skipped:', (e as Error).message);
  // }

  // try {
  //   strategies.push(
  //     new DevtoStrategy({
  //       apiKey: 'your-api-key',
  //     }),
  //   );
  // } catch (e) {
  //   if (verbose) console.error('[smposter] DevtoStrategy skipped:', (e as Error).message);
  // }

  return strategies;
}

/** main */
async function main(opts: CliOptions): Promise<void> {
  if (opts.help) return void printHelp();
  if (opts.version) return void console.log(getVersion());

  loadEnv();

  if (opts.verbose) {
    console.error('[smposter] cwd:', process.cwd());
    console.error('[smposter] strategies will be built from placeholders/env');
  }

  const text = await promptText(500, opts.verbose);

  const strategies = buildStrategies(opts.verbose);
  if (strategies.length === 0) {
    console.error('[smposter] No strategies configured. Nothing to post.');
    process.exitCode = 1;
    return;
  }

  const client = new Client({ strategies });

  // AbortController integration: timeout and Ctrl+C
  const controller = new AbortController();
  const timeoutMs = 60000; // adjust later via env/flag if desired
  const t = setTimeout(() => controller.abort(new Error('Timeout exceeded')), timeoutMs);

  process.once('SIGINT', () => {
    console.error('\n[smposter] Aborting on SIGINT');
    controller.abort(new Error('Aborted by user (SIGINT)'));
  });

  console.log(text);

  try {
    await client.post(text, { signal: controller.signal });
    console.log('[smposter] Posted successfully.');
  } catch (err) {
    if ((err as Error).name === 'AbortError') {
      console.error('[smposter] Post aborted:', (err as Error).message);
    } else {
      console.error('[smposter] Post failed:', (err as Error).message);
    }
    process.exitCode = 1;
  } finally {
    clearTimeout(t);
  }
}

/* ---------- robust direct-invocation check ---------- */
function isInvokedDirectly(): boolean {
  try {
    const argvPath = fs.realpathSync(process.argv[1] ?? '');
    const filePath = fs.realpathSync(__filename);
    return argvPath === filePath;
  } catch {
    return true;
  }
}

if (isInvokedDirectly()) {
  const opts = parseArgs(process.argv);
  main(opts).catch((err: unknown) => {
    const msg = err instanceof Error ? err.stack ?? err.message : String(err);
    console.error('[smposter] error:', msg);
    process.exitCode = 1;
  });
}

export { parseArgs, printHelp, getVersion, main, loadEnv, type CliOptions };
