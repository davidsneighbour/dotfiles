import { lstat } from "node:fs/promises";
import { resolve } from "node:path";
import { loadConfig, OBSERVATIONS, type SyncRepository } from "./config.ts";
import { repositoryInfo } from "./git.ts";
import { prepareImport } from "./importer.ts";
import { aggregateStatus, commitIdentity, type ObjectFormat } from "./model.ts";
import { assertPrivate } from "./privacy.ts";
import { fetchOrigin, type RefTips, stableScan } from "./scan.ts";
import {
  PENDING,
  publishTransaction,
  recoverTransaction,
} from "./transaction.ts";
import {
  ARCHIVE,
  atomicWrite,
  digest,
  notes,
  optionalRead,
  parseNote,
  record,
  safePath,
  serialise,
  sorted,
  strings,
  withLock,
} from "./vault.ts";
import { observationWrites } from "./views.ts";

export interface RepositoryOutcome {
  id: string;
  complete: boolean;
  selected: number;
  changed: number;
  error?: string;
}
export interface SyncResult {
  repositories: RepositoryOutcome[];
  failed: number;
  dryRun: boolean;
  recovered: boolean;
}
export interface SyncOptions {
  vault: string;
  dryRun?: boolean;
  report?: (outcome: RepositoryOutcome) => void;
}
interface Observation {
  last_attempt: string;
  complete: boolean;
  last_success?: {
    at: string;
    refs: RefTips;
    selected: number;
    clone: string;
    fetch: "never" | "origin";
    scope: string[];
  };
  error?: string;
}
function safeError(error: unknown): string {
  if (error instanceof SyntaxError)
    return "Invalid JSON state; inspect or rebuild the operational cache";
  if ((error as NodeJS.ErrnoException)?.code)
    return "Local files are unavailable; check clone paths, vault permissions, and storage";
  if (error instanceof Error && error.name === "Error") return error.message;
  return "Incomplete sync; check local objects, configuration, and permissions";
}
function parseObservations(
  source: string | undefined,
): Record<string, Observation> {
  if (!source) return {};
  const value = record(JSON.parse(source) as unknown);
  if (value["schema_version"] !== 1)
    throw new Error("Unsupported observations schema");
  const entries = record(value["repositories"]);
  for (const raw of Object.values(entries)) {
    const entry = record(raw);
    if (
      typeof entry["last_attempt"] !== "string" ||
      typeof entry["complete"] !== "boolean"
    )
      throw new Error(
        "Invalid observation state; rebuild operational state from notes",
      );
    if (entry["last_success"] !== undefined) {
      const success = record(entry["last_success"]);
      if (
        typeof success["at"] !== "string" ||
        !Number.isFinite(Date.parse(success["at"]))
      )
        throw new Error("Invalid last-success observation");
    }
  }
  return entries as unknown as Record<string, Observation>;
}
const observationText = (entries: Record<string, Observation>): string =>
  `${JSON.stringify({ schema_version: 1, repositories: entries }, null, 2)}\n`;
async function chooseClone(config: SyncRepository): Promise<string> {
  for (const path of config.paths) {
    try {
      if ((await lstat(path)).isDirectory()) return path;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
  }
  throw new Error(
    "No configured clone is available; restore a complete clone before syncing",
  );
}
function reconcile(
  source: string,
  id: string,
  hashes: Set<string>,
  format: ObjectFormat,
  now: string,
): string {
  const note = parseNote(source);
  const p = note.properties;
  if (
    p["type"] !== "git-commit" ||
    p["schema_version"] !== 1 ||
    p["object_format"] !== format ||
    typeof p["hash"] !== "string"
  )
    throw new Error(
      "Invalid membership note or repository object format changed",
    );
  commitIdentity(format, p["hash"]);
  if (p["body_sha256"] !== digest(note.body))
    throw new Error(
      "Commit body conflict; preserve or repair the edit before syncing",
    );
  const ids = strings(p["repository_ids"], "repository_ids");
  const reachable = strings(p["reachable_in"], "reachable_in");
  const unreachable = strings(p["unreachable_in"], "unreachable_in");
  const unknown = strings(p["unknown_in"], "unknown_in");
  const all = [...reachable, ...unreachable, ...unknown];
  if (
    new Set(all).size !== all.length ||
    ids.length !== new Set(ids).size ||
    all.length !== ids.length ||
    all.some((member) => !ids.includes(member))
  )
    throw new Error("Invalid membership observations");
  const lists = {
    reachable_in: reachable.filter((member) => member !== id),
    unreachable_in: unreachable.filter((member) => member !== id),
    unknown_in: unknown.filter((member) => member !== id),
  };
  if (hashes.has(p["hash"])) lists.reachable_in.push(id);
  else lists.unreachable_in.push(id);
  const status = aggregateStatus(
    ids.map((repository_id) => ({
      repository_id,
      status: lists.reachable_in.includes(repository_id)
        ? "reachable"
        : lists.unreachable_in.includes(repository_id)
          ? "unreachable"
          : "unknown",
    })),
  );
  const properties = {
    ...p,
    reachable_in: sorted(lists.reachable_in),
    unreachable_in: sorted(lists.unreachable_in),
    unknown_in: sorted(lists.unknown_in),
    status,
    status_changed_at: p["status"] === status ? p["status_changed_at"] : now,
  };
  if (serialise(properties, note.body, note) === serialise(p, note.body, note))
    return source;
  return serialise({ ...properties, updated: now }, note.body, note);
}
export async function syncVault(options: SyncOptions): Promise<SyncResult> {
  const vault = resolve(options.vault);
  await safePath(vault, "");
  if (!(await lstat(vault)).isDirectory())
    throw new Error("--vault must be an existing directory");
  async function run(): Promise<SyncResult> {
    if (options.dryRun && (await optionalRead(await safePath(vault, PENDING))))
      throw new Error(
        "Interrupted sync needs recovery; dry-run will not modify its journal",
      );
    const recovered = options.dryRun ? false : await recoverTransaction(vault);
    const config = await loadConfig(vault);
    let observationSource = await optionalRead(
      await safePath(vault, OBSERVATIONS),
    );
    let observations = parseObservations(observationSource);
    const outcomes: RepositoryOutcome[] = [];
    const seen = new Map<string, string>();
    // Keep one parsed archive snapshot under the writer lock. Publication still checks each destination.
    const archiveItems = await notes(vault, `${ARCHIVE}/items`);
    for (const entry of config.repositories) {
      let outcome: RepositoryOutcome;
      try {
        const repo = await chooseClone(entry);
        const initial = repositoryInfo(repo);
        if ((initial.remote ?? null) !== entry.canonical_remote)
          throw new Error(
            "Configured canonical remote differs from origin; confirm repository identity and update sync config",
          );
        const owner = seen.get(initial.common);
        if (owner && owner !== entry.id)
          throw new Error(
            "One common Git directory is configured under multiple repository IDs",
          );
        seen.set(initial.common, entry.id);
        if (!options.dryRun) fetchOrigin(repo, entry);
        const stable = await stableScan(repo, entry, async (objects, info) => {
          const plan = await prepareImport(
            { repo, vault, repositoryId: entry.id, dryRun: options.dryRun },
            objects,
            info,
            undefined,
            archiveItems,
          );
          const candidates = new Map<string, string>();
          for (const [path, note] of archiveItems)
            if (
              note.properties["type"] !== "git-commit-redirect" &&
              strings(
                note.properties["repository_ids"],
                "repository_ids",
              ).includes(entry.id)
            )
              candidates.set(path, note.source);
          for (const [path, content] of plan.writes)
            if (
              path.startsWith(`${ARCHIVE}/items/`) &&
              parseNote(content).properties["type"] !== "git-commit-redirect"
            )
              candidates.set(path, content);
          for (const [path, source] of candidates)
            if (!plan.originals.has(path)) plan.originals.set(path, source);
          const hashes = new Set(objects.map((object) => object.hash));
          const now = new Date().toISOString();
          for (const [path, content] of candidates) {
            if (
              plan.writes.has(path) &&
              parseNote(plan.writes.get(path) ?? "").properties["type"] ===
                "git-commit-redirect"
            )
              continue;
            plan.writes.set(
              path,
              reconcile(content, entry.id, hashes, info.format, now),
            );
          }
          let changed = 0;
          for (const [path, content] of plan.writes)
            if (
              path.endsWith(".md") &&
              (await optionalRead(await safePath(vault, path))) !== content
            )
              changed++;
          return {
            writes: plan.writes,
            originals: plan.originals,
            selected: objects.length,
            changed,
          };
        });
        const observation: Observation = {
          last_attempt: stable.observedAt,
          complete: true,
          last_success: {
            at: stable.observedAt,
            refs: stable.tips,
            selected: stable.prepared.selected,
            clone: repo,
            fetch: options.dryRun ? "never" : entry.fetch,
            scope: sorted([...entry.refs, "refs/tags/"]),
          },
        };
        const next = { ...observations, [entry.id]: observation };
        for (const [path, content] of await observationWrites(
          vault,
          observationText(next),
          stable.prepared.writes,
        ))
          stable.prepared.writes.set(path, content);
        stable.prepared.writes.set(OBSERVATIONS, observationText(next));
        stable.prepared.originals.set(OBSERVATIONS, observationSource);
        if (!options.dryRun) {
          assertPrivate(vault, [...stable.prepared.writes.keys()]);
          await publishTransaction(
            vault,
            stable.prepared.writes,
            stable.prepared.originals,
          );
          for (const [path, content] of stable.prepared.writes)
            if (path.startsWith(`${ARCHIVE}/items/`))
              archiveItems.set(path, parseNote(content));
          observationSource = observationText(next);
          observations = next;
        }
        outcome = {
          id: entry.id,
          complete: true,
          selected: stable.prepared.selected,
          changed: stable.prepared.changed,
        };
      } catch (error) {
        const message = safeError(error);
        outcome = {
          id: entry.id,
          complete: false,
          selected: 0,
          changed: 0,
          error: message,
        };
        if (!options.dryRun) {
          const previous = observations[entry.id];
          observations = {
            ...observations,
            [entry.id]: {
              ...previous,
              last_attempt: new Date().toISOString(),
              complete: false,
              error: message,
            },
          };
          if (!(await optionalRead(await safePath(vault, PENDING)))) {
            observationSource = observationText(observations);
            const failureWrites = await observationWrites(
              vault,
              observationSource,
            );
            failureWrites.set(OBSERVATIONS, observationSource);
            assertPrivate(vault, [...failureWrites.keys()]);
            for (const [path, content] of failureWrites)
              await atomicWrite(vault, path, content);
          }
        }
      }
      outcomes.push(outcome);
      options.report?.(outcome);
      if (
        !options.dryRun &&
        (await optionalRead(await safePath(vault, PENDING)))
      )
        throw new Error(
          "Sync recovery is incomplete; stop other writers and resolve pending.json before continuing",
        );
    }
    return {
      repositories: outcomes,
      failed: outcomes.filter((outcome) => !outcome.complete).length,
      dryRun: Boolean(options.dryRun),
      recovered,
    };
  }
  return options.dryRun ? run() : withLock(vault, run);
}
