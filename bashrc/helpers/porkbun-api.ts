#!/usr/bin/env ts-node

/**
 * Porkbun TypeScript domain info fetcher
 * Fetches metadata, name servers, DNS records, URL forwards, glue records, SSL info.
 * Logs raw JSON output to file and prints a human-readable summary.
 */

import https from 'https';
import { URL } from 'url';
import { writeFile } from 'fs/promises';
import path from 'path';

const API_BASE = 'https://api.porkbun.com/api/json/v3';

const API_KEY = process.env.PORKBUN_APIKEY;
const SECRET_KEY = process.env.PORKBUN_SECKEY;

if (!API_KEY || !SECRET_KEY) {
  console.error('Error: PORKBUN_APIKEY and PORKBUN_SECKEY environment variables must be set.');
  process.exit(1);
}

interface BaseRequest {
  apikey: string;
  secretapikey: string;
}

interface BaseResponse {
  status: 'SUCCESS' | 'ERROR';
  message?: string;
}

// Domain listAll response
interface DomainMetadata {
  domain: string;
  status: string;
  createDate: string;
  expireDate: string;
  autoRenew: boolean;
  whoisPrivacy: boolean;
  securityLock: boolean;
  labels?: { title: string; color?: string }[];
}

interface ListAllResponse extends BaseResponse {
  domains?: DomainMetadata[];
}

// Get NS response
interface GetNsResponse extends BaseResponse {
  ns?: string[];
}

// DNS retrieve response
interface DnsRecord {
  id: number;
  type: string;
  name: string;
  content: string;
  ttl: number;
  priority?: number;
  // other fields possible depending on record type
}

interface DnsRetrieveResponse extends BaseResponse {
  records?: DnsRecord[];
}

// URL forwarding response
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

// Glue records response
interface GlueHost {
  host: string;
  v4: string[] | null;
  v6: string[] | null;
}
interface GlueResponse extends BaseResponse {
  hosts?: GlueHost[];
}

// SSL retrieve response (structure may vary; approximate)
interface SslInfo {
  certs?: Record<string, unknown>[]; // or more precise types if known
  [key: string]: unknown;
}
interface SslRetrieveResponse extends BaseResponse {
  ssl?: SslInfo;
}

type PorkbunResponse =
  | ListAllResponse
  | GetNsResponse
  | DnsRetrieveResponse
  | UrlForwardResponse
  | GlueResponse
  | SslRetrieveResponse;

async function post<T extends BaseResponse>(pathname: string, body: BaseRequest): Promise<T> {
  const url = new URL(API_BASE + pathname);
  const data = JSON.stringify(body);

  return new Promise<T>((resolve, reject) => {
    const req = https.request(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        'User-Agent': 'porkbun-ts-client/1.0',
      },
    }, (res) => {
      let chunks: Buffer[] = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        const str = Buffer.concat(chunks).toString();
        let json: unknown;
        try {
          json = JSON.parse(str);
        } catch (err) {
          return reject(new Error(`Failed to parse JSON from ${pathname}: ${err}`));
        }
        const resp = json as T;
        if (res.statusCode !== 200) {
          return reject(new Error(`HTTP ${res.statusCode} from ${pathname}: ${str}`));
        }
        if (resp.status !== 'SUCCESS') {
          return reject(new Error(`API error from ${pathname}: ${resp.message || JSON.stringify(resp)}`));
        }
        resolve(resp);
      });
    });

    req.on('error', (err) => {
      reject(new Error(`Request error to ${pathname}: ${err.message}`));
    });

    req.write(data);
    req.end();
  });
}

interface DomainInfoDump {
  listAll?: ListAllResponse;
  getNs?: GetNsResponse;
  dns?: DnsRetrieveResponse;
  urlForwards?: UrlForwardResponse;
  glue?: GlueResponse;
  ssl?: SslRetrieveResponse;
}

async function gatherDomainInfo(domain: string): Promise<DomainInfoDump> {
  const credentials: BaseRequest = { apikey: API_KEY, secretapikey: SECRET_KEY };
  const result: DomainInfoDump = {};

  try {
    result.listAll = await post<ListAllResponse>('/domain/listAll', credentials);
  } catch (e: any) {
    console.warn('Warning: listAll failed:', e.message);
  }

  try {
    result.getNs = await post<GetNsResponse>(`/domain/getNs/${domain}`, credentials);
  } catch (e: any) {
    console.warn('Warning: getNs failed:', e.message);
  }

  try {
    result.dns = await post<DnsRetrieveResponse>(`/dns/retrieve/${domain}`, credentials);
  } catch (e: any) {
    console.warn('Warning: dns/retrieve failed:', e.message);
  }

  try {
    result.urlForwards = await post<UrlForwardResponse>(`/domain/getUrlForwarding/${domain}`, credentials);
  } catch (e: any) {
    console.warn('Warning: getUrlForwarding failed:', e.message);
  }

  try {
    result.glue = await post<GlueResponse>(`/domain/getGlue/${domain}`, credentials);
  } catch (e: any) {
    console.warn('Warning: getGlue failed:', e.message);
  }

  try {
    result.ssl = await post<SslRetrieveResponse>(`/ssl/retrieve/${domain}`, credentials);
  } catch (e: any) {
    console.warn('Warning: ssl/retrieve failed:', e.message);
  }

  return result;
}

function printSummary(domain: string, data: DomainInfoDump): void {
  console.log(`\n=== Porkbun domain info for: ${domain} ===`);

  if (data.listAll?.domains) {
    const d = data.listAll.domains.find(x => x.domain === domain);
    if (d) {
      console.log('Domain metadata:');
      console.log(`  Status: ${d.status}`);
      console.log(`  Created: ${d.createDate}`);
      console.log(`  Expires: ${d.expireDate}`);
      console.log(`  AutoRenew: ${d.autoRenew}`);
      console.log(`  WhoisPrivacy: ${d.whoisPrivacy}`);
      console.log(`  SecurityLock: ${d.securityLock}`);
      if (d.labels && d.labels.length) {
        console.log('  Labels: ' + d.labels.map(l => l.title + (l.color ? `(${l.color})` : '')).join(', '));
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
    for (const r of data.dns.records) {
      const prio = r.priority !== undefined ? ` prio=${r.priority}` : '';
      console.log(`  [${r.type}] ${r.name} → ${r.content} (TTL ${r.ttl}${prio})`);
    }
  }

  if (data.urlForwards?.forwards) {
    console.log('URL Forwards:');
    for (const f of data.urlForwards.forwards) {
      console.log(`  Subdomain: '${f.subdomain}' → ${f.location}, type: ${f.type}, includePath: ${f.includePath}, wildcard: ${f.wildcard}`);
    }
  }

  if (data.glue?.hosts) {
    console.log('Glue Records:');
    for (const h of data.glue.hosts) {
      console.log(`  ${h.host} → IPv4: ${h.v4?.join(', ') || '-'} ; IPv6: ${h.v6?.join(', ') || '-'}`);
    }
  }

  if (data.ssl) {
    console.log('SSL Info:');
    console.dir(data.ssl, { depth: 3 });
  }

  console.log('=== End of summary ===\n');
}

async function main() {
  const domain = process.argv[2];
  if (!domain) {
    console.error('Usage: ts-node getPorkbunInfo.ts <domain>');
    process.exit(1);
  }

  try {
    const info = await gatherDomainInfo(domain);
    printSummary(domain, info);

    const dumpFile = path.resolve(`porkbun_${domain.replace(/\W+/g, '_')}_dump.json`);
    await writeFile(dumpFile, JSON.stringify(info, null, 2), 'utf-8');
    console.log(`Full JSON dump written to ${dumpFile}`);
  } catch (err: any) {
    console.error('Fatal error:', err.message);
    process.exit(2);
  }
}

main().catch((err) => {
  console.error('Unexpected error:', err);
  process.exit(99);
});
