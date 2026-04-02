#!/usr/bin/env node

import { cp, mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

/**
 * Custom backup task example for backup-runner.ts.
 *
 * The runner provides these environment variables:
 * - BACKUP_TASK_DIR
 * - BACKUP_WORK_DIR
 * - BACKUP_ARCHIVE_PATH
 * - BACKUP_TIMESTAMP
 * - BACKUP_NAME
 * - BACKUP_HOST
 */

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

async function main(): Promise<void> {
  const taskDirectory = requireEnv('BACKUP_TASK_DIR');
  const workDirectory = requireEnv('BACKUP_WORK_DIR');
  const timestamp = requireEnv('BACKUP_TIMESTAMP');
  const name = requireEnv('BACKUP_NAME');
  const host = requireEnv('BACKUP_HOST');

  await mkdir(workDirectory, { recursive: true });

  const manifest = [
    `name=${name}`,
    `host=${host}`,
    `timestamp=${timestamp}`,
    `source=${taskDirectory}`,
  ].join('\n');

  await writeFile(resolve(workDirectory, 'manifest.txt'), `${manifest}\n`, 'utf8');

  const dataDirectory = resolve(taskDirectory, 'data');
  await cp(dataDirectory, resolve(workDirectory, 'data'), {
    recursive: true,
    force: true,
    errorOnExist: false,
  }).catch((error: unknown) => {
    if (error instanceof Error && /ENOENT/u.test(error.message)) {
      return;
    }
    throw error;
  });

  console.log(`Custom backup for ${name} completed.`);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[ERROR] ${message}`);
  process.exitCode = 1;
});
