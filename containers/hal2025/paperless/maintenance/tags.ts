#!/usr/bin/env node
/**
 * create-year-month-tags.ts
 * Loads PAPERLESS_BASE_URL and PAPERLESS_TOKEN from .env (current folder first, then repo root fallback).
 */

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import dotenv from "dotenv";

/**
 * Try to load .env from (a) CWD, (b) script directory, (c) repo root (two levels up).
 */
function loadEnv(): void {
  const candidates = [
    path.resolve(process.cwd(), ".env"),
    path.resolve(path.dirname(new URL(import.meta.url).pathname), ".env"),
    path.resolve(path.dirname(new URL(import.meta.url).pathname), "..", "..", ".env"),
  ];

  for (const file of candidates) {
    if (fs.existsSync(file)) {
      dotenv.config({ path: file });
      return;
    }
  }
}

function mustGetEnv(name: string): string {
  const v = process.env[name];
  if (!v || !v.trim()) throw new Error(`Missing required env var: ${name}`);
  return v.trim();
}

function normaliseBaseUrl(baseUrl: string): string {
  const u = baseUrl.replace(/\/+$/, "");
  if (!/^https?:\/\//i.test(u)) throw new Error(`PAPERLESS_BASE_URL must start with http:// or https:// (got: ${baseUrl})`);
  return u;
}

loadEnv();

const PAPERLESS_BASE_URL = normaliseBaseUrl(mustGetEnv("PAPERLESS_BASE_URL"));
const PAPERLESS_TOKEN = mustGetEnv("PAPERLESS_TOKEN");

// From here, reuse the earlier logic:
// - list tags
// - create parent year
// - create month children
// (omitted in this snippet for brevity; you can paste the previous implementation under this point)

console.log(`Loaded env OK. Base URL: ${PAPERLESS_BASE_URL}`);
// process.exit(0);
