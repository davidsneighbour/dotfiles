import { randomUUID } from "node:crypto";
import { lstat } from "node:fs/promises";
import { basename, resolve } from "node:path";
import { repositoryInfo, type Selection, selectCommits } from "./git.ts";
import {
  aggregateStatus,
  type CommitObject,
  commitDate,
  commitIdentity,
  commitItemPath,
  STORAGE_TIMEZONE,
} from "./model.ts";
import { assertPrivate } from "./privacy.ts";
import { publishTransaction } from "./transaction.ts";
import {
  ARCHIVE,
  digest,
  type Note,
  notes,
  optionalRead,
  parseNote,
  record,
  STATE,
  safePath,
  serialise,
  sorted,
  strings,
  withLock,
} from "./vault.ts";

export interface ImportTarget {
  repo: string;
  vault: string;
  repositoryId?: string | undefined;
  dryRun?: boolean | undefined;
}
export interface ImportOptions extends ImportTarget, Selection {}
export interface ImportPlan {
  writes: Map<string, string>;
  originals: Map<string, string | undefined>;
  result: ImportResult;
}
export interface ImportResult {
  selected: number;
  changed: number;
  repositoryId: string;
  dryRun: boolean;
}
export const validId = (id: string): boolean =>
  /^github-[1-9]\d*$/.test(id) ||
  /^local-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(
    id,
  );
function validateNote(note: Note, type: string): void {
  if (
    note.properties["type"] !== type ||
    note.properties["schema_version"] !== 1
  )
    throw new Error(`Unsupported ${type} schema`);
  if (note.properties["labels"] !== undefined)
    strings(note.properties["labels"], "labels");
}
export async function importCommits(
  options: ImportOptions,
): Promise<ImportResult> {
  const modes =
    Number(options.commit !== undefined) +
    Number(options.recent !== undefined) +
    Number(options.from !== undefined || options.to !== undefined);
  if (modes !== 1 || Boolean(options.from) !== Boolean(options.to))
    throw new Error(
      "Choose exactly one of --commit, --recent, or --from with --to",
    );
  if (
    options.recent !== undefined &&
    (!Number.isSafeInteger(options.recent) || options.recent < 1)
  )
    throw new Error("--recent must be a positive integer");
  if (options.commit && options.ref)
    throw new Error("--ref cannot be combined with --commit");
  if (options.repositoryId && !validId(options.repositoryId))
    throw new Error(
      "Invalid --repository-id; use local-UUID or an existing verified github-ID",
    );
  const repo = resolve(options.repo);
  const vault = resolve(options.vault);
  await safePath(vault, "");
  if (!(await lstat(vault)).isDirectory())
    throw new Error("--vault must be an existing directory");
  const info = repositoryInfo(repo);
  const commits = selectCommits(repo, info.format, options);
  async function run(): Promise<ImportResult> {
    const pending = await optionalRead(
      await safePath(vault, ".obsidian/git-commit-reports/pending.json"),
    );
    if (pending)
      throw new Error(
        "Interrupted sync requires recovery; run sync before importing",
      );
    const plan = await prepareImport(options, commits, info);
    if (!options.dryRun) {
      assertPrivate(vault, [...plan.writes.keys()]);
      await publishTransaction(vault, plan.writes, plan.originals);
    }
    return plan.result;
  }
  if (options.dryRun) return run();
  return withLock(vault, run);
}

// Caller holds the vault lock when applying this plan. Preparation never writes.
export async function prepareImport(
  options: ImportTarget,
  commits: CommitObject[],
  info: ReturnType<typeof repositoryInfo>,
  overlay?: Map<string, string>,
  existingItems?: Map<string, Note>,
): Promise<ImportPlan> {
  const repo = resolve(options.repo);
  const vault = resolve(options.vault);
  const read = async (path: string) =>
    overlay?.get(path) ?? (await optionalRead(await safePath(vault, path)));
  const repoNotes = await notes(vault, `${ARCHIVE}/repositories`, overlay);
  const cacheSource = await read(STATE);
  const cache = cacheSource ? record(JSON.parse(cacheSource) as unknown) : {};
  const ids = new Map<string, { path: string; note: Note }>();
  for (const [path, note] of repoNotes) {
    validateNote(note, "git-repository");
    const id = note.properties["repository_id"];
    if (
      typeof id !== "string" ||
      !validId(id) ||
      path !== `${ARCHIVE}/repositories/${id}.md` ||
      ids.has(id)
    )
      throw new Error("Invalid or duplicate repository identity");
    strings(note.properties["former_slugs"], "former_slugs");
    ids.set(id, { path, note });
  }
  const matches = [...ids].filter(
    ([, entry]) => info.remote && entry.note.properties["url"] === info.remote,
  );
  const cached = cache[info.common];
  if (cached !== undefined && (typeof cached !== "string" || !validId(cached)))
    throw new Error("Invalid repository identity cache");
  if (matches.length > 1 && !options.repositoryId)
    throw new Error(
      "Remote has multiple registered identities; supply --repository-id",
    );
  const id =
    options.repositoryId ??
    (typeof cached === "string" ? cached : matches[0]?.[0]) ??
    `local-${randomUUID()}`;
  if (cached && cached !== id)
    throw new Error(
      "Repository ID conflicts with its persisted clone registration",
    );
  const previous = ids.get(id)?.note;
  if (id.startsWith("github-") && !previous)
    throw new Error(
      "New GitHub IDs require API verification, which is not implemented; use an assigned local UUID",
    );
  if (
    !options.repositoryId &&
    previous &&
    info.remote &&
    previous.properties["url"] !== info.remote
  )
    throw new Error(
      "Origin changed; confirm identity explicitly with --repository-id",
    );
  const now = new Date().toISOString();
  const slug = info.remote
    ? new URL(info.remote).pathname.slice(1)
    : basename(repo);
  const former = previous
    ? strings(previous.properties["former_slugs"], "former_slugs")
    : [];
  if (
    previous &&
    previous.properties["slug"] !== slug &&
    typeof previous.properties["slug"] === "string"
  )
    former.push(previous.properties["slug"]);
  const repository: Record<string, unknown> = {
    ...previous?.properties,
    type: "git-repository",
    schema_version: 1,
    repository_id: id,
    title: slug,
    host: info.remote ? new URL(info.remote).host : "local",
    slug,
    former_slugs: sorted(former),
    retired: previous?.properties["retired"] ?? false,
    created: previous?.properties["created"] ?? now,
    updated: previous?.properties["updated"] ?? now,
    labels: previous?.properties["labels"] ?? [],
  };
  if (info.remote) repository["url"] = info.remote;
  const writes = new Map<string, string>();
  const originals = new Map<string, string | undefined>([[STATE, cacheSource]]);
  const repositoryPath = `${ARCHIVE}/repositories/${id}.md`;
  let repositoryContent = serialise(repository, previous?.body ?? "", previous);
  if (
    previous &&
    repositoryContent !==
      serialise(previous.properties, previous.body, previous)
  ) {
    repository["updated"] = now;
    repositoryContent = serialise(repository, previous.body, previous);
  }
  writes.set(repositoryPath, repositoryContent);
  originals.set(repositoryPath, previous?.source);
  const index = new Map<string, { path: string; note: Note }>();
  for (const [path, note] of existingItems ??
    (await notes(vault, `${ARCHIVE}/items`, overlay))) {
    if (note.properties["type"] === "git-commit-redirect") continue;
    validateNote(note, "git-commit");
    const p = note.properties;
    if (
      (p["object_format"] !== "sha1" && p["object_format"] !== "sha256") ||
      typeof p["hash"] !== "string"
    )
      throw new Error(`Invalid commit identity in ${path}`);
    const key = commitIdentity(p["object_format"], p["hash"]);
    if (index.has(key))
      throw new Error(`Duplicate commit identity: ${p["hash"]}`);
    index.set(key, { path, note });
  }
  for (const commit of commits) {
    const entry = index.get(commitIdentity(commit.object_format, commit.hash));
    const existing = entry?.note;
    const p = existing?.properties;
    const path = commitItemPath(commit);
    const enriching =
      p?.["metadata_complete"] === false && p["source"] === "legacy-report";
    if (entry && entry.path !== path && !enriching)
      throw new Error(`Commit is stored at a conflicting path: ${commit.hash}`);
    if (entry && entry.path !== path) {
      const target = await read(path);
      if (
        target &&
        parseNote(target).properties["type"] !== "git-commit-redirect"
      )
        throw new Error(
          "Enrichment destination conflicts with an existing note",
        );
      originals.set(path, target);
    }
    const { message, ...immutable } = commit;
    if (p) {
      if (p["metadata_complete"] !== true && !enriching)
        throw new Error("Unsupported incomplete commit provenance");
      for (const [key, value] of Object.entries(enriching ? {} : immutable))
        if (JSON.stringify(p[key]) !== JSON.stringify(value))
          throw new Error(
            `Immutable metadata conflict for ${commit.hash}: ${key}`,
          );
      if (
        p["body_sha256"] !== digest(existing?.body ?? "") ||
        (!enriching && existing?.body !== message)
      )
        throw new Error(
          `Commit body conflict for ${commit.hash}; preserve or repair the edit explicitly`,
        );
    }
    const repositoryIds = sorted([
      ...(p ? strings(p["repository_ids"], "repository_ids") : []),
      id,
    ]);
    const reachable = p ? strings(p["reachable_in"], "reachable_in") : [];
    const unreachable = p ? strings(p["unreachable_in"], "unreachable_in") : [];
    const unknown = p ? strings(p["unknown_in"], "unknown_in") : [];
    const memberships = [...reachable, ...unreachable, ...unknown];
    if (
      new Set(memberships).size !== memberships.length ||
      memberships.some((member) => !repositoryIds.includes(member))
    )
      throw new Error("Invalid membership observations");
    // A selected object proves availability, not reachability in configured refs.
    for (const member of repositoryIds)
      if (!memberships.includes(member)) unknown.push(member);
    const status = aggregateStatus(
      repositoryIds.map((repository_id) => ({
        repository_id,
        status: reachable.includes(repository_id)
          ? "reachable"
          : unreachable.includes(repository_id)
            ? "unreachable"
            : "unknown",
      })),
    );
    const properties: Record<string, unknown> = {
      ...p,
      ...immutable,
      type: "git-commit",
      schema_version: 1,
      date: commitDate(commit.committed_at),
      date_basis: "committer",
      timezone: STORAGE_TIMEZONE,
      parent_count: commit.parents.length,
      is_merge: commit.parents.length > 1,
      repository_ids: repositoryIds,
      repositories: repositoryIds.map(
        (member) => `[[${ARCHIVE}/repositories/${member}]]`,
      ),
      commit_urls: sorted([
        ...(p ? strings(p["commit_urls"], "commit_urls") : []),
        ...(info.remote && new URL(info.remote).hostname === "github.com"
          ? [`${info.remote}/commit/${commit.hash}`]
          : []),
      ]),
      reachable_in: sorted(reachable),
      unreachable_in: sorted(unreachable),
      unknown_in: sorted(unknown),
      status,
      status_changed_at:
        p?.["status"] === status ? p["status_changed_at"] : now,
      created: p?.["created"] ?? now,
      updated: p?.["updated"] ?? now,
      metadata_complete: true,
      source: "git",
      legacy_reports: p?.["legacy_reports"] ?? [],
      labels: p?.["labels"] ?? [],
      tags: sorted([
        ...(p?.["tags"] !== undefined ? strings(p["tags"], "tags") : []),
        "git-commit",
      ]),
      body_sha256: digest(message),
    };
    const classification = /^(\w+)(?:\(([^)]+)\))?(!)?:\s/.exec(commit.title);
    if (classification) {
      properties["commit_type"] = classification[1];
      if (classification[2]) properties["commit_scope"] = classification[2];
      properties["breaking_change"] =
        Boolean(classification[3]) || /^BREAKING[ -]CHANGE:/m.test(message);
    }
    let content = serialise(properties, message, existing);
    if (
      existing &&
      content !== serialise(existing.properties, existing.body, existing)
    ) {
      properties["updated"] = now;
      content = serialise(properties, message, existing);
    }
    writes.set(path, content);
    if (!originals.has(path)) originals.set(path, existing?.source);
    if (entry && entry.path !== path) {
      originals.set(entry.path, existing?.source);
      writes.set(
        entry.path,
        serialise(
          {
            type: "git-commit-redirect",
            schema_version: 1,
            redirect_to: `[[${path.slice(0, -3)}]]`,
          },
          `This report-only item was enriched from its Git object. Open [[${path.slice(0, -3)}|the canonical commit]].\n`,
        ),
      );
    }
  }
  // Preflight every destination before making any content changes.
  let changed = 0;
  for (const [path, content] of writes)
    if ((await read(path)) !== content) changed++;
  cache[info.common] = id;
  // Persist assigned identities first so interrupted imports can reuse them.
  const ordered = new Map([
    [STATE, `${JSON.stringify(cache, null, 2)}\n`],
    ...writes,
  ]);
  return {
    writes: ordered,
    originals,
    result: {
      selected: commits.length,
      changed,
      repositoryId: id,
      dryRun: Boolean(options.dryRun),
    },
  };
}
