#!/usr/bin/env ts-node

/**
 * Porkbun TypeScript domain info fetcher
 * Fetches metadata, name servers, DNS records, URL forwards, glue records, SSL info.
 * Logs raw JSON output to file and prints a human-readable summary.
 */

/**
 * @see https://porkbun.com/api/json/v3/documentation
 */

import { appendFile, mkdir, writeFile } from 'node:fs/promises';
import https from 'node:https';
import os from 'node:os';
import path from 'node:path';

const API_BASE = 'https://api.porkbun.com/api/json/v3';
const LOG_DIR = path.join(os.homedir(), '.logs', 'api');

const API_KEY = process.env['PORKBUN_APIKEY'];
const SECRET_KEY = process.env['PORKBUN_SECKEY'];

interface BaseRequest {
  apikey: string;
  secretapikey: string;
}

interface BaseResponse {
  status: 'SUCCESS' | 'ERROR';
  message?: string;
}

interface DomainMetadata {
  domain: string;
  status: string;
  createDate: string;
  expireDate: string;
  autoRenew: boolean;
  whoisPrivacy: boolean;
  securityLock: boolean;
  labels?: Array<{ title: string; color?: string }>;
}

interface ListAllResponse extends BaseResponse {
  domains?: DomainMetadata[];
}

interface GetNsResponse extends BaseResponse {
  ns?: string[];
}

interface DnsRecord {
  id: number;
  type: string;
  name: string;
  content: string;
  ttl: number;
  priority?: number;
}

interface DnsRetrieveResponse extends BaseResponse {
  records?: DnsRecord[];
}

interface UrlForward {
  subdomain: string;
  location: string;
  type: string;
  includePath: boolean;
  wildcard: boolean;
}

interface UrlForwardResponse extends BaseResponse {
  forwards?: UrlForward[];
}

interface GlueHost {
  host: string;
  v4: string[] | null;
  v6: string[] | null;
}

interface GlueResponse extends BaseResponse {
  hosts?: GlueHost[];
}

interface SslInfo {
  certs?: Record<string, unknown>[];
  [key: string]: unknown;
}

interface SslRetrieveResponse extends BaseResponse {
  ssl?: SslInfo;
}

interface DomainInfoDump {
  listAll?: ListAllResponse;
  getNs?: GetNsResponse;
  dns?: DnsRetrieveResponse;
  urlForwards?: UrlForwardResponse;
  glue?: GlueResponse;
  ssl?: SslRetrieveResponse;
}

interface CliOptions {
  domain?: string;
  listDomains: boolean;
  verbose: boolean;
  help: boolean;
}

function timestampNow(): string {
  const now = new Date();
  const yyyy = String(now.getFullYear());
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const dd = String(now.getDate()).padStart(2, '0');
  const hh = String(now.getHours()).padStart(2, '0');
  const mi = String(now.getMinutes()).padStart(2, '0');
  const ss = String(now.getSeconds()).padStart(2, '0');
  return `${yyyy}${mm}${dd}-${hh}${mi}${ss}`;
}

async function ensureLogDir(): Promise<void> {
  await mkdir(LOG_DIR, { recursive: true });
}

function usage(): string {
  return [
    'Usage:',
    '  node bashrc/helpers/api/porkbun-api.ts --domain <domain.tld> [--verbose]',
    '  node bashrc/helpers/api/porkbun-api.ts --list-domains [--verbose]',
    '',
    'Flags:',
    '  --domain <domain>   Domain to inspect via Porkbun APIs',
    '  --list-domains      List all domains available with API key/secret pair',
    '  --verbose           Enable additional logging output',
    '  --help              Show this help message',
    '',
    'Environment variables:',
    '  PORKBUN_APIKEY',
    '  PORKBUN_SECKEY',
  ].join('\n');
}

function parseArgs(args: string[]): CliOptions {
  const options: CliOptions = {
    listDomains: false,
    verbose: false,
    help: false,
  };

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];

    if (!arg) {
      continue;
    }

    if (arg === '--help') {
      options.help = true;
      continue;
    }

    if (arg === '--verbose') {
      options.verbose = true;
      continue;
    }

    if (arg === '--list-domains') {
      options.listDomains = true;
      continue;
    }

    if (arg === '--domain') {
      const value = args[i + 1];
      if (!value || value.startsWith('--')) {
        throw new Error('Missing value for --domain.');
      }
      options.domain = value;
      i += 1;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return options;
}

async function post<T extends BaseResponse>(
  pathname: string,
  body: BaseRequest,
): Promise<T> {
  const url = new URL(`${API_BASE}${pathname}`);
  const payload = JSON.stringify(body);

  return new Promise<T>((resolve, reject) => {
    const req = https.request(
      url,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
          'User-Agent': 'porkbun-ts-client/2.0',
        },
      },
      (res) => {
        const chunks: Buffer[] = [];

        res.on('data', (chunk: Buffer | string) => {
          const normalized =
            typeof chunk === 'string' ? Buffer.from(chunk) : chunk;
          chunks.push(normalized);
        });

        res.on('end', () => {
          const responseBody = Buffer.concat(chunks).toString('utf8');
          let json: unknown;

          try {
            json = JSON.parse(responseBody);
          } catch (error: unknown) {
            const message =
              error instanceof Error ? error.message : String(error);
            reject(
              new Error(`Failed to parse JSON from ${pathname}: ${message}`),
            );
            return;
          }

          if (res.statusCode !== 200) {
            reject(
              new Error(
                `HTTP ${String(res.statusCode)} from ${pathname}: ${responseBody}`,
              ),
            );
            return;
          }

          const parsed = json as T;
          if (parsed.status !== 'SUCCESS') {
            reject(
              new Error(
                `API error from ${pathname}: ${parsed.message ?? JSON.stringify(parsed)}`,
              ),
            );
            return;
          }

          resolve(parsed);
        });
      },
    );

    req.on('error', (error: Error) => {
      reject(new Error(`Request error to ${pathname}: ${error.message}`));
    });

    req.write(payload);
    req.end();
  });
}

async function gatherDomainInfo(
  credentials: BaseRequest,
  domain: string,
  verbose: boolean,
): Promise<DomainInfoDump> {
  const result: DomainInfoDump = {};

  try {
    result.listAll = await post<ListAllResponse>(
      '/domain/listAll',
      credentials,
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`Warning: listAll failed: ${message}`);
  }

  try {
    result.getNs = await post<GetNsResponse>(
      `/domain/getNs/${domain}`,
      credentials,
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`Warning: getNs failed: ${message}`);
  }

  try {
    result.dns = await post<DnsRetrieveResponse>(
      `/dns/retrieve/${domain}`,
      credentials,
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`Warning: dns/retrieve failed: ${message}`);
  }

  try {
    result.urlForwards = await post<UrlForwardResponse>(
      `/domain/getUrlForwarding/${domain}`,
      credentials,
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`Warning: getUrlForwarding failed: ${message}`);
  }

  try {
    result.glue = await post<GlueResponse>(
      `/domain/getGlue/${domain}`,
      credentials,
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`Warning: getGlue failed: ${message}`);
  }

  try {
    result.ssl = await post<SslRetrieveResponse>(
      `/ssl/retrieve/${domain}`,
      credentials,
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`Warning: ssl/retrieve failed: ${message}`);
  }

  if (verbose) {
    console.log('Finished API collection for domain info.');
  }

  return result;
}

function printSummary(domain: string, data: DomainInfoDump): void {
  console.log(`\n=== Porkbun domain info for: ${domain} ===`);

  if (data.listAll?.domains) {
    const meta = data.listAll.domains.find((entry) => entry.domain === domain);
    if (meta) {
      console.log('Domain metadata:');
      console.log(`  Status: ${meta.status}`);
      console.log(`  Created: ${meta.createDate}`);
      console.log(`  Expires: ${meta.expireDate}`);
      console.log(`  AutoRenew: ${String(meta.autoRenew)}`);
      console.log(`  WhoisPrivacy: ${String(meta.whoisPrivacy)}`);
      console.log(`  SecurityLock: ${String(meta.securityLock)}`);
      if (meta.labels && meta.labels.length > 0) {
        console.log(
          `  Labels: ${meta.labels.map((label) => `${label.title}${label.color ? `(${label.color})` : ''}`).join(', ')}`,
        );
      }
    } else {
      console.log('Warning: domain not found in listAll response.');
    }
  }

  if (data.getNs?.ns) {
    console.log('Authoritative name servers (registry):');
    for (const ns of data.getNs.ns) {
      console.log(`  - ${ns}`);
    }
  }

  if (data.dns?.records) {
    console.log('DNS Records:');
    for (const record of data.dns.records) {
      const priority =
        record.priority !== undefined ? ` prio=${String(record.priority)}` : '';
      console.log(
        `  [${record.type}] ${record.name} → ${record.content} (TTL ${String(record.ttl)}${priority})`,
      );
    }
  }

  if (data.urlForwards?.forwards) {
    console.log('URL Forwards:');
    for (const forward of data.urlForwards.forwards) {
      console.log(
        `  Subdomain: '${forward.subdomain}' → ${forward.location}, type: ${forward.type}, includePath: ${String(
          forward.includePath,
        )}, wildcard: ${String(forward.wildcard)}`,
      );
    }
  }

  if (data.glue?.hosts) {
    console.log('Glue Records:');
    for (const host of data.glue.hosts) {
      console.log(
        `  ${host.host} → IPv4: ${host.v4?.join(', ') ?? '-'} ; IPv6: ${host.v6?.join(', ') ?? '-'}`,
      );
    }
  }

  if (data.ssl) {
    console.log('SSL Info:');
    console.dir(data.ssl, { depth: 3 });
  }

  console.log('=== End of summary ===\n');
}

function printDomainList(listAll: ListAllResponse): void {
  const domains = listAll.domains ?? [];
  if (domains.length === 0) {
    console.log('No domains returned by Porkbun for this API key pair.');
    return;
  }

  console.log('Domains available for this Porkbun API key pair:');
  for (const domain of domains) {
    console.log(`  - ${domain.domain}`);
  }
}

async function writeRunArtifacts(
  data: unknown,
): Promise<{ logFile: string; jsonDumpFile: string }> {
  await ensureLogDir();
  const ts = timestampNow();
  const logFile = path.join(LOG_DIR, `porkbun-${ts}.log`);
  const jsonDumpFile = path.join(LOG_DIR, `porkbun-dump-${ts}.json`);

  await writeFile(jsonDumpFile, JSON.stringify(data, null, 2), 'utf8');
  await appendFile(
    logFile,
    `[${new Date().toISOString()}] Wrote JSON dump to ${jsonDumpFile}\n`,
    'utf8',
  );

  return { logFile, jsonDumpFile };
}

async function main(): Promise<void> {
  let options: CliOptions;

  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Error: ${message}`);
    console.log('');
    console.log(usage());
    process.exit(1);
    return;
  }

  if (options.help || process.argv.length <= 2) {
    console.log(usage());
    return;
  }

  if (!API_KEY || !SECRET_KEY) {
    console.error(
      'Error: PORKBUN_APIKEY and PORKBUN_SECKEY environment variables must be set.',
    );
    process.exit(1);
  }

  const credentials: BaseRequest = {
    apikey: API_KEY,
    secretapikey: SECRET_KEY,
  };

  if (options.listDomains) {
    const listAll = await post<ListAllResponse>('/domain/listAll', credentials);
    printDomainList(listAll);
    const files = await writeRunArtifacts({ listAll, mode: 'list-domains' });
    console.log(`Log file written to ${files.logFile}`);
    console.log(`JSON dump written to ${files.jsonDumpFile}`);
    return;
  }

  if (!options.domain) {
    console.error('Error: --domain is required unless --list-domains is used.');
    console.log('');
    console.log(usage());
    process.exit(1);
    return;
  }

  const domain = options.domain;
  const info = await gatherDomainInfo(credentials, domain, options.verbose);
  printSummary(domain, info);

  const files = await writeRunArtifacts({ domain, info, mode: 'domain-info' });
  console.log(`Log file written to ${files.logFile}`);
  console.log(`JSON dump written to ${files.jsonDumpFile}`);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Fatal error: ${message}`);
  process.exit(2);
});
