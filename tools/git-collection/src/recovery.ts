import { randomUUID } from "node:crypto";
import {
  chmodSync,
  closeSync,
  existsSync,
  linkSync,
  mkdirSync,
  openSync,
  unlinkSync,
} from "node:fs";
import { dirname, resolve } from "node:path";
import { backup, type DatabaseSync } from "node:sqlite";
import { openDatabase, verifyDatabase } from "./database.ts";
import type { DiscoveryConfig } from "./discovery.ts";
import { type ScanSummary, scanAll } from "./scanner.ts";

function temporaryDestination(destination: string): string {
  if (existsSync(destination))
    throw new Error(
      "Destination already exists. Choose a new file; existing files are never overwritten.",
    );
  mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
  const path = `${destination}.${randomUUID()}.partial`;
  closeSync(openSync(path, "wx", 0o600));
  return path;
}

export async function snapshotDatabase(
  db: DatabaseSync,
  destination: string,
): Promise<void> {
  const target = resolve(destination);
  const temporary = temporaryDestination(target);
  try {
    await backup(db, temporary);
    const snapshot = openDatabase(temporary);
    try {
      verifyDatabase(snapshot);
    } finally {
      snapshot.close();
    }
    chmodSync(temporary, 0o600);
    linkSync(temporary, target);
  } finally {
    unlinkSync(temporary);
  }
}

export async function rebuild(
  destination: string,
  config: DiscoveryConfig,
): Promise<ScanSummary> {
  const target = resolve(destination);
  const temporary = temporaryDestination(target);
  try {
    const db = openDatabase(temporary, true);
    let summary: ScanSummary;
    try {
      summary = await scanAll(db, temporary, config, true);
      if (summary.failures)
        throw new Error(
          `Rebuild failed for ${summary.failures} path(s): ${JSON.stringify(summary.errors)}`,
        );
      verifyDatabase(db);
    } finally {
      db.close();
    }
    linkSync(temporary, target);
    return summary;
  } finally {
    unlinkSync(temporary);
  }
}
