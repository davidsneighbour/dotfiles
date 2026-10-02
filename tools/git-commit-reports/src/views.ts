import { readFile } from "node:fs/promises";
import { OBSERVATIONS } from "./config.ts";
import { validId } from "./importer.ts";
import { assertPrivate } from "./privacy.ts";
import { PENDING, publishTransaction } from "./transaction.ts";
import {
  ARCHIVE,
  notes,
  optionalRead,
  record,
  safePath,
  serialise,
  withLock,
} from "./vault.ts";

export async function viewWrites(vault: string): Promise<Map<string, string>> {
  const writes = new Map<string, string>();
  for (const name of ["Commits", "Repositories"]) {
    const path = `${ARCHIVE}/${name}.base`;
    const content = await readFile(
      new URL(`../templates/${name}.base`, import.meta.url),
      "utf8",
    );
    const existing = await optionalRead(await safePath(vault, path));
    if (existing !== undefined && existing !== content)
      throw new Error(
        "Existing Base differs from the template; preserve custom changes and merge manually",
      );
    writes.set(path, content);
  }
  for (const [path, content] of await observationWrites(vault))
    writes.set(path, content);
  return writes;
}
export async function observationWrites(
  vault: string,
  state?: string,
  overlay?: Map<string, string>,
): Promise<Map<string, string>> {
  const writes = new Map<string, string>();
  const source =
    state ?? (await optionalRead(await safePath(vault, OBSERVATIONS)));
  const observations = source
    ? record(record(JSON.parse(source) as unknown)["repositories"])
    : {};
  for (const note of (
    await notes(vault, `${ARCHIVE}/repositories`, overlay)
  ).values()) {
    const id = note.properties["repository_id"];
    if (typeof id !== "string" || !validId(id))
      throw new Error("Invalid repository ID for observation view");
    const raw = observations[id];
    const entry = raw ? record(raw) : {};
    const success = entry["last_success"] ? record(entry["last_success"]) : {};
    writes.set(
      `${ARCHIVE}/observations/${id}.md`,
      serialise(
        {
          type: "git-observation-view",
          repository: `[[${ARCHIVE}/repositories/${id}]]`,
          complete: entry["complete"] ?? false,
          last_attempt: entry["last_attempt"] ?? null,
          last_success: success["at"] ?? null,
          fetch: success["fetch"] ?? null,
          error: entry["error"] ?? null,
        },
        "Generated presentation of operational state. Refresh with the views command; timestamps belong to the observation, not the commit.\n",
      ),
    );
  }
  return writes;
}
export async function installViews(
  vault: string,
  dryRun = false,
): Promise<number> {
  async function run() {
    if (await optionalRead(await safePath(vault, PENDING)))
      throw new Error(
        "Recover the pending publication before installing views",
      );
    const writes = await viewWrites(vault);
    let changed = 0;
    for (const [path, content] of writes)
      if ((await optionalRead(await safePath(vault, path))) !== content)
        changed++;
    if (!dryRun) {
      assertPrivate(
        vault,
        [...writes.keys()].filter((path) => path.endsWith(".md")),
      );
      await publishTransaction(vault, writes);
    }
    return changed;
  }
  return dryRun ? run() : withLock(vault, run);
}
