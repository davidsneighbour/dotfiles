import { lstat, mkdir, rmdir } from "node:fs/promises";
import { join } from "node:path";
import { dateBoundary } from "./git.ts";
import { assertPrivate } from "./privacy.ts";
import { type SyncOptions, type SyncResult, syncVault } from "./sync.ts";
import { atomicWrite, optionalRead, record, safePath } from "./vault.ts";

export const SCHEDULE = ".obsidian/git-commit-reports/schedule.json";
const LOCK = ".obsidian/git-commit-reports/schedule.lock";
export function dueDay(now: Date): string {
  if (!Number.isFinite(now.getTime()))
    throw new Error("Invalid scheduler time");
  // The daily run is due at 08:00 Asia/Bangkok (UTC+07:00, no DST).
  return new Date(now.getTime() - 60 * 60 * 1000).toISOString().slice(0, 10);
}
export async function scheduledSync(
  options: SyncOptions & { ifDue?: boolean; now?: Date },
  sync: (options: SyncOptions) => Promise<SyncResult> = syncVault,
): Promise<SyncResult | undefined> {
  const vault = await safePath(options.vault, "");
  if (!(await lstat(vault)).isDirectory())
    throw new Error("--vault must be an existing directory");
  const now = options.now ?? new Date();
  const day = dueDay(now);
  async function run() {
    const source = await optionalRead(await safePath(options.vault, SCHEDULE));
    if (source && options.ifDue) {
      const state = record(JSON.parse(source) as unknown);
      if (state["schema_version"] !== 1 || typeof state["day"] !== "string")
        throw new Error(
          "Invalid schedule state; preserve or rebuild schedule.json",
        );
      dateBoundary(state["day"]);
      if (state["day"] >= day) return undefined;
    }
    const result = await sync(options);
    if (!options.dryRun && result.failed === 0) {
      assertPrivate(options.vault, [SCHEDULE]);
      await atomicWrite(
        options.vault,
        SCHEDULE,
        `${JSON.stringify({ schema_version: 1, day, completed_at: new Date().toISOString() })}\n`,
      );
    }
    return result;
  }
  if (options.dryRun) return run();
  const lock = await safePath(options.vault, LOCK);
  assertPrivate(options.vault, [SCHEDULE, `${LOCK}/owner.json`]);
  await mkdir(join(lock, ".."), { recursive: true });
  try {
    await mkdir(lock);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "EEXIST")
      throw new Error(
        "Scheduled sync is already running; after a crash, stop writers before removing schedule.lock",
      );
    throw error;
  }
  try {
    return await run();
  } finally {
    await rmdir(lock);
  }
}
