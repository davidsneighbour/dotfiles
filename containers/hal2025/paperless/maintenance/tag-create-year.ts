#!/usr/bin/env node

import path from "node:path";
import readline from "node:readline";
import process from "node:process";
import dotenv from "dotenv";

dotenv.config({ path: path.resolve(process.cwd(), ".env") });

function mustGetEnv(name: string): string {
  const v = process.env[name];
  if (!v || !v.trim()) throw new Error(`Missing required env var: ${name}`);
  return v.trim();
}

const BASE_URL = mustGetEnv("PAPERLESS_BASE_URL").replace(/\/+$/, "");
const TOKEN = mustGetEnv("PAPERLESS_TOKEN");

interface Tag {
  id: number;
  name: string;
  parent: number | null;
  color: string | null;
}

interface ListResponse<T> {
  results: T[];
  next: string | null;
}

const TAG_COLOR = "#FFFF80";

const MONTHS = [
  "january",
  "february",
  "march",
  "april",
  "may",
  "june",
  "july",
  "august",
  "september",
  "october",
  "november",
  "december",
] as const;

async function api<T>(url: string, options: RequestInit = {}): Promise<T> {
  const res = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Token ${TOKEN}`,
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(options.headers ?? {}),
    },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`HTTP ${res.status} ${res.statusText}\n${body}`);
  }

  return res.json() as Promise<T>;
}

async function getAllTags(): Promise<Tag[]> {
  const tags: Tag[] = [];
  let url: string | null = `${BASE_URL}/api/tags/?page_size=1000`;

  while (url) {
    const page = await api<ListResponse<Tag>>(url);
    tags.push(...page.results);
    url = page.next;
  }

  return tags;
}

function findTag(tags: Tag[], name: string, parent: number | null): Tag | undefined {
  return tags.find((t) => t.name === name && (t.parent ?? null) === parent);
}

async function createTag(name: string, parent: number | null): Promise<Tag> {
  return api<Tag>(`${BASE_URL}/api/tags/`, {
    method: "POST",
    body: JSON.stringify({ name, parent, color: TAG_COLOR }),
  });
}

function ask(question: string): Promise<string> {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) =>
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    }),
  );
}

async function main(): Promise<void> {
  const yearInput = await ask("Enter year (e.g. 2026): ");
  if (!/^\d{4}$/.test(yearInput)) throw new Error("Year must be a 4-digit number");

  const year = Number(yearInput);
  const tags = await getAllTags();

  // Parent year tag (still OK because year names are unique)
  let yearTag = findTag(tags, String(year), null);

  if (!yearTag) {
    console.log(`Creating parent tag: ${year}`);
    yearTag = await createTag(String(year), null);
    tags.push(yearTag);
  } else {
    console.log(`Parent tag already exists: ${year}`);
  }

  // Month tags MUST be globally unique, so prefix with year
  for (let i = 0; i < MONTHS.length; i++) {
    const mm = String(i + 1).padStart(2, "0");
    const childName = `${year}-${mm}-${MONTHS[i]}`;
    const existing = findTag(tags, childName, yearTag.id);

    if (existing) {
      console.log(`Exists: ${year} -> ${childName}`);
      continue;
    }

    console.log(`Creating: ${year} -> ${childName}`);
    const created = await createTag(childName, yearTag.id);
    tags.push(created);
  }

  console.log("Done.");
}

main().catch((err: unknown) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
