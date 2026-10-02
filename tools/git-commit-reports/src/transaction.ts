import { open, unlink } from "node:fs/promises";
import { dirname } from "node:path";
import {
  ARCHIVE,
  atomicWrite,
  optionalRead,
  record,
  STATE,
  safePath,
} from "./vault.ts";

export const PENDING = ".obsidian/git-commit-reports/pending.json";
interface Change {
  path: string;
  before: string | null;
  after: string;
}
interface Journal {
  schema_version: 1;
  changes: Change[];
}
async function remove(vault: string, path: string): Promise<void> {
  try {
    const absolute = await safePath(vault, path);
    await unlink(absolute);
    const directory = await open(dirname(absolute), "r");
    try {
      await directory.sync();
    } finally {
      await directory.close();
    }
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
  }
}
function parseJournal(source: string): Journal {
  const value = record(JSON.parse(source) as unknown);
  if (value["schema_version"] !== 1 || !Array.isArray(value["changes"]))
    throw new Error("Invalid pending sync journal; preserve it for recovery");
  const paths = new Set<string>();
  const changes = value["changes"].map((raw: unknown): Change => {
    const change = record(raw);
    const path = change["path"];
    const before = change["before"];
    const after = change["after"];
    if (
      typeof path !== "string" ||
      (before !== null && typeof before !== "string") ||
      typeof after !== "string" ||
      paths.has(path) ||
      path === PENDING ||
      path.split("/").some((part) => part === "." || part === ".." || !part) ||
      (!(
        (path.endsWith(".md") &&
          ["items", "repositories", "observations"].some((folder) =>
            path.startsWith(`${ARCHIVE}/${folder}/`),
          )) ||
        path === `${ARCHIVE}/Commits.base` ||
        path === `${ARCHIVE}/Repositories.base`
      ) &&
        path !== STATE &&
        path !== ".obsidian/git-commit-reports/observations.json" &&
        path !== ".obsidian/git-commit-reports/migration-repositories.json")
    )
      throw new Error(
        "Invalid pending sync journal entry; preserve it for recovery",
      );
    paths.add(path);
    return { path, before, after };
  });
  return { schema_version: 1, changes };
}
// Roll back an interrupted publication before taking a new observation. Caller holds the lock.
export async function recoverTransaction(vault: string): Promise<boolean> {
  const source = await optionalRead(await safePath(vault, PENDING));
  if (!source) return false;
  const journal = parseJournal(source);
  for (const change of journal.changes) {
    const current =
      (await optionalRead(await safePath(vault, change.path))) ?? null;
    if (current !== change.before && current !== change.after)
      throw new Error(
        "Sync recovery conflicts with an external edit; preserve the journal and resolve the edited note",
      );
  }
  for (const change of [...journal.changes].reverse()) {
    if (change.before === null) await remove(vault, change.path);
    else await atomicWrite(vault, change.path, change.before);
  }
  await remove(vault, PENDING);
  return true;
}
export async function publishTransaction(
  vault: string,
  writes: Map<string, string>,
  originals?: Map<string, string | undefined>,
): Promise<number> {
  if (await optionalRead(await safePath(vault, PENDING)))
    throw new Error("Pending sync must be recovered before publication");
  const changes: Change[] = [];
  for (const [path, after] of writes) {
    const before = (await optionalRead(await safePath(vault, path))) ?? null;
    if (
      originals?.has(path) &&
      before !== (originals.get(path) ?? null) &&
      before !== after
    )
      throw new Error(
        "Archive changed during scan; retry after stopping external edits",
      );
    if (before !== after) changes.push({ path, before, after });
  }
  if (!changes.length) return 0;
  // Validate before publication as well as recovery: legacy reports are never destinations.
  parseJournal(JSON.stringify({ schema_version: 1, changes }));
  await atomicWrite(
    vault,
    PENDING,
    `${JSON.stringify({ schema_version: 1, changes })}\n`,
  );
  try {
    for (const change of changes)
      await atomicWrite(vault, change.path, change.after);
    await remove(vault, PENDING);
  } catch (error) {
    try {
      await recoverTransaction(vault);
    } catch {
      throw new Error(
        "Sync publication failed and rollback is incomplete; preserve pending.json and run sync recovery after checking permissions and external edits",
      );
    }
    throw error;
  }
  return changes.filter((change) => change.path.endsWith(".md")).length;
}
