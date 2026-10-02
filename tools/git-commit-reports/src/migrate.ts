import { randomUUID } from "node:crypto";
import { lstat, readdir } from "node:fs/promises";
import { join } from "node:path";
import { CONFIG, parseConfig } from "./config.ts";
import { readAvailableCommits, repositoryInfo } from "./git.ts";
import { prepareImport, validId } from "./importer.ts";
import {
  type Inventory,
  inventoryLegacy,
  type LegacyEvidence,
} from "./legacy.ts";
import { aggregateStatus, type CommitObject } from "./model.ts";
import { assertPrivate } from "./privacy.ts";
import {
  PENDING,
  publishTransaction,
  recoverTransaction,
} from "./transaction.ts";
import {
  ARCHIVE,
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

export const MIGRATION_IDS =
  ".obsidian/git-commit-reports/migration-repositories.json";
export interface MigrationResult {
  inventory: Omit<Inventory, "evidence">;
  recovered: number;
  reportOnly: number;
  changed: number;
  failures: number;
  registered: number;
}
export interface MigrationOptions {
  vault: string;
  cloneRoots?: string[];
  dryRun?: boolean;
  report?: (summary: string) => void;
}
async function discover(roots: string[]): Promise<Map<string, string>> {
  const found = new Map<string, string>();
  for (const root of roots) {
    const owners = await readdir(root, { withFileTypes: true });
    for (const owner of owners.filter((entry) => entry.isDirectory())) {
      for (const candidate of await readdir(join(root, owner.name), {
        withFileTypes: true,
      })) {
        if (!candidate.isDirectory()) continue;
        const path = join(root, owner.name, candidate.name);
        try {
          await lstat(join(path, ".git"));
        } catch (error) {
          if ((error as NodeJS.ErrnoException).code === "ENOENT") continue;
          throw error;
        }
        const info = repositoryInfo(path);
        if (info.remote && !found.has(info.remote))
          found.set(info.remote, path);
      }
    }
  }
  return found;
}
function propertiesFromEvidence(
  evidence: LegacyEvidence[],
  id: string,
  previous: ReturnType<typeof parseNote> | undefined,
  now: string,
) {
  const p = previous?.properties;
  if (previous && p?.["body_sha256"] !== digest(previous.body))
    throw new Error(
      "Existing migrated body conflicts with its recorded digest; preserve the edit",
    );
  const ids = sorted([
    ...(p ? strings(p["repository_ids"], "repository_ids") : []),
    id,
  ]);
  const reachable = p ? strings(p["reachable_in"], "reachable_in") : [];
  const unreachable = p ? strings(p["unreachable_in"], "unreachable_in") : [];
  const unknown = p ? strings(p["unknown_in"], "unknown_in") : [];
  if (![...reachable, ...unreachable, ...unknown].includes(id))
    unknown.push(id);
  const status = aggregateStatus(
    ids.map((repository_id) => ({
      repository_id,
      status: reachable.includes(repository_id)
        ? "reachable"
        : unreachable.includes(repository_id)
          ? "unreachable"
          : "unknown",
    })),
  );
  const body =
    previous?.body ??
    "Report-only evidence. The full Git message, identities, parents, and timestamps have not been recovered.\n";
  const first = evidence[0];
  if (!first) throw new Error("Missing legacy evidence");
  const historical = p?.["legacy_evidence"];
  const retained =
    historical === undefined
      ? []
      : Array.isArray(historical)
        ? historical
        : (() => {
            throw new Error("Invalid legacy evidence property");
          })();
  const combined = [...retained, ...evidence].map((value) =>
    JSON.stringify(value),
  );
  const properties: Record<string, unknown> = {
    ...p,
    type: "git-commit",
    schema_version: 1,
    hash: first.hash,
    object_format: first.hash.length === 40 ? "sha1" : "sha256",
    title: p?.["title"] ?? (first.title || "(subject unavailable)"),
    date: p?.["date"] ?? first.date,
    timezone: "Asia/Bangkok",
    date_basis:
      p?.["metadata_complete"] === true
        ? "committer"
        : "legacy-report-provisional",
    repository_ids: ids,
    repositories: ids.map((member) => `[[${ARCHIVE}/repositories/${member}]]`),
    reachable_in: sorted(reachable),
    unreachable_in: sorted(unreachable),
    unknown_in: sorted(unknown),
    status,
    status_changed_at: p?.["status"] === status ? p["status_changed_at"] : now,
    created: p?.["created"] ?? now,
    updated: p?.["updated"] ?? now,
    source: p?.["source"] ?? "legacy-report",
    metadata_complete: p?.["metadata_complete"] ?? false,
    legacy_reports: sorted([
      ...(p ? strings(p["legacy_reports"], "legacy_reports") : []),
      ...evidence.map((entry) => `[[${entry.report.slice(0, -3)}]]`),
    ]),
    legacy_evidence: sorted(combined).map(
      (value) => JSON.parse(value) as unknown,
    ),
    commit_urls: sorted([
      ...(p ? strings(p["commit_urls"], "commit_urls") : []),
      ...evidence.map((entry) => entry.url),
    ]),
    labels: p?.["labels"] ?? [],
    tags: sorted([
      ...(p?.["tags"] ? strings(p["tags"], "tags") : []),
      "git-commit",
    ]),
    body_sha256: digest(body),
  };
  if (
    previous &&
    serialise(properties, body, previous) !==
      serialise(previous.properties, previous.body, previous)
  )
    properties["updated"] = now;
  return { properties, body };
}
export async function migrateLegacy(
  options: MigrationOptions,
): Promise<MigrationResult> {
  const vault = options.vault;
  async function run(): Promise<MigrationResult> {
    if (options.dryRun && (await optionalRead(await safePath(vault, PENDING))))
      throw new Error("Pending publication must be recovered before dry-run");
    if (!options.dryRun) await recoverTransaction(vault);
    const overlay = options.dryRun ? new Map<string, string>() : undefined;
    const read = async (path: string) =>
      overlay?.get(path) ?? (await optionalRead(await safePath(vault, path)));
    const inventory = await inventoryLegacy(vault);
    const discovered = await discover(options.cloneRoots ?? []);
    const configuration = await optionalRead(await safePath(vault, CONFIG));
    const configured = configuration
      ? parseConfig(configuration).repositories
      : [];
    for (const entry of configured)
      if (entry.canonical_remote)
        for (const path of entry.paths) {
          try {
            if (repositoryInfo(path).remote === entry.canonical_remote) {
              discovered.set(entry.canonical_remote, path);
              break;
            }
          } catch {
            options.report?.(
              "A configured clone is unavailable; preserving report-only evidence where necessary",
            );
          }
        }
    const identitiesSource = await optionalRead(
      await safePath(vault, MIGRATION_IDS),
    );
    const identities = identitiesSource
      ? record(JSON.parse(identitiesSource) as unknown)
      : {};
    const repoNotes = await notes(vault, `${ARCHIVE}/repositories`);
    const byRemote = new Map<string, ReturnType<typeof parseNote>>();
    for (const note of repoNotes.values())
      if (typeof note.properties["url"] === "string") {
        const url = note.properties["url"];
        if (byRemote.has(url))
          throw new Error(
            "Multiple repository records use the same remote; resolve identity before migration",
          );
        byRemote.set(url, note);
      }
    const remoteGroups = new Map<string, LegacyEvidence[]>();
    for (const evidence of inventory.evidence) {
      const group = remoteGroups.get(evidence.repository_url) ?? [];
      group.push(evidence);
      remoteGroups.set(evidence.repository_url, group);
    }
    const { evidence: _evidence, ...counts } = inventory;
    const result: MigrationResult = {
      inventory: counts,
      recovered: 0,
      reportOnly: 0,
      changed: 0,
      failures: 0,
      registered: 0,
    };
    for (const [remote, evidence] of remoteGroups) {
      const previousRepository = byRemote.get(remote);
      const known =
        previousRepository?.properties["repository_id"] ??
        configured.find((entry) => entry.canonical_remote === remote)?.id ??
        identities[remote];
      const id = typeof known === "string" ? known : `local-${randomUUID()}`;
      if (!validId(id) || (id.startsWith("github-") && !previousRepository))
        throw new Error(
          "Legacy repository identity requires an existing verified record or local UUID",
        );
      identities[remote] = id;
      const writes = new Map<string, string>();
      const originals = new Map<string, string | undefined>();
      const now = new Date().toISOString();
      const repositoryPath = `${ARCHIVE}/repositories/${id}.md`;
      const repository = previousRepository?.properties ?? {
        type: "git-repository",
        schema_version: 1,
        repository_id: id,
        title: new URL(remote).pathname.slice(1),
        host: new URL(remote).host,
        slug: new URL(remote).pathname.slice(1),
        former_slugs: [],
        url: remote,
        retired: false,
        labels: [],
        created: now,
        updated: now,
      };
      writes.set(
        repositoryPath,
        serialise(
          repository,
          previousRepository?.body ?? "",
          previousRepository,
        ),
      );
      originals.set(repositoryPath, previousRepository?.source);
      if (!previousRepository) result.registered++;
      const index = new Map<
        string,
        { path: string; note: ReturnType<typeof parseNote> }
      >();
      for (const [path, note] of await notes(
        vault,
        `${ARCHIVE}/items`,
        overlay,
      )) {
        if (note.properties["type"] === "git-commit-redirect") continue;
        const hash = note.properties["hash"];
        if (typeof hash !== "string" || index.has(hash))
          throw new Error(
            "Invalid or duplicate canonical hash during migration",
          );
        index.set(hash, { path, note });
      }
      const grouped = new Map<string, LegacyEvidence[]>();
      for (const entry of evidence) {
        const group = grouped.get(entry.hash) ?? [];
        group.push(entry);
        grouped.set(entry.hash, group);
      }
      for (const [hash, entries] of grouped) {
        const old = index.get(hash);
        const first = entries[0];
        if (!first) throw new Error("Missing evidence");
        const path =
          old?.path ??
          `${ARCHIVE}/items/${first.date.replaceAll("-", "/")}/${hash}.md`;
        const enriched = propertiesFromEvidence(entries, id, old?.note, now);
        writes.set(
          path,
          serialise(enriched.properties, enriched.body, old?.note),
        );
        originals.set(path, old?.note.source);
      }
      const path = discovered.get(remote);
      let recovered = new Map<string, CommitObject>();
      if (path) {
        const info = repositoryInfo(path);
        if (info.remote !== remote)
          throw new Error("Clone origin changed during migration");
        recovered = readAvailableCommits(
          path,
          [...grouped.keys()].filter(
            (hash) => hash.length === (info.format === "sha1" ? 40 : 64),
          ),
          info.format,
        );
      }
      for (const [hash, object] of recovered) {
        const previous = index.get(hash)?.note;
        if (previous?.properties["metadata_complete"] === true) {
          const { message, ...immutable } = object;
          if (
            previous.body !== message ||
            Object.entries(immutable).some(
              ([key, value]) =>
                JSON.stringify(previous.properties[key]) !==
                JSON.stringify(value),
            )
          )
            throw new Error(
              "Recovered object conflicts with existing immutable metadata or body",
            );
        }
      }
      // Stage report provenance first; complete objects then enrich through the shared importer.
      writes.set(MIGRATION_IDS, `${JSON.stringify(identities, null, 2)}\n`);
      originals.set(
        MIGRATION_IDS,
        await optionalRead(await safePath(vault, MIGRATION_IDS)),
      );
      for (const [destination, content] of writes)
        if (
          destination.endsWith(".md") &&
          (await read(destination)) !== content
        )
          result.changed++;
      if (!options.dryRun) {
        assertPrivate(vault, [...writes.keys()]);
        await publishTransaction(vault, writes, originals);
      }
      result.recovered += recovered.size;
      result.reportOnly += grouped.size - recovered.size;
      if (overlay)
        for (const [destination, content] of writes)
          overlay.set(destination, content);
      if (path && recovered.size) {
        const plan = await prepareImport(
          { vault, repo: path, repositoryId: id },
          [...recovered.values()],
          repositoryInfo(path),
          overlay,
        );
        if (options.dryRun) result.changed += plan.result.changed;
        else {
          assertPrivate(vault, [...plan.writes.keys()]);
          result.changed += await publishTransaction(
            vault,
            plan.writes,
            plan.originals,
          );
        }
        if (overlay)
          for (const [destination, content] of plan.writes)
            overlay.set(destination, content);
      }
      options.report?.(
        `Legacy memberships processed=${result.recovered + result.reportOnly} recovered=${result.recovered} report-only=${result.reportOnly}`,
      );
    }
    return result;
  }
  return options.dryRun ? run() : withLock(vault, run);
}
