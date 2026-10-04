import type { DatabaseSync } from "node:sqlite";
import { safeError } from "./collector.ts";
import { gitFields } from "./git.ts";

interface FileStatistics {
  path: string;
  insertions: number | null;
  deletions: number | null;
}

export async function enrich(
  db: DatabaseSync,
  options: { repository?: string; files?: boolean; limit?: number },
): Promise<{
  enriched: number;
  failures: number;
  errors: { repository: string; hash: string; error: string }[];
}> {
  const limit = options.limit ?? 500;
  if (!Number.isInteger(limit) || limit < 1 || limit > 100000)
    throw new Error("--limit must be from 1 to 100000 for enrichment.");
  const candidates = db
    .prepare(`SELECT c.repository_id, c.hash, r.path FROM commits c
    JOIN repositories r ON r.id=c.repository_id
    LEFT JOIN commit_enrichment e ON e.repository_id=c.repository_id AND e.hash=c.hash
    WHERE (e.state IS NULL OR e.state='failed' OR (?=1 AND e.files_complete=0))
      AND (? IS NULL OR r.id=? OR r.name=? OR r.path=?)
    ORDER BY CASE WHEN e.state='failed' THEN 1 ELSE 0 END, c.repository_id, c.hash LIMIT ?`)
    .all(
      Number(options.files ?? false),
      options.repository ?? null,
      options.repository ?? null,
      options.repository ?? null,
      options.repository ?? null,
      limit,
    );
  const result = {
    enriched: 0,
    failures: 0,
    errors: [] as { repository: string; hash: string; error: string }[],
  };
  for (const candidate of candidates) {
    const repository = String(candidate.path);
    const hash = String(candidate.hash);
    const id = String(candidate.repository_id);
    let transaction = false;
    try {
      // Read the raw parent header: Git log/show hide parents at shallow boundaries.
      let firstParent: string | undefined;
      for await (const header of gitFields(
        repository,
        ["cat-file", "commit", hash],
        "",
        10,
      )) {
        if (header === "") break;
        if (!firstParent && header.startsWith("parent "))
          firstParent = header.slice(7);
      }
      const trees = firstParent ? [firstParent, hash] : [hash];
      const flags = [
        "diff-tree",
        "--root",
        "--no-commit-id",
        "-r",
        "--no-renames",
        "--no-ext-diff",
        "--no-textconv",
      ];
      const statistics: FileStatistics[] = [];
      for await (const field of gitFields(
        repository,
        [...flags, "--numstat", "-z", ...trees],
        "",
        0,
      )) {
        const firstTab = field.indexOf("\t");
        const secondTab = field.indexOf("\t", firstTab + 1);
        if (firstTab < 0 || secondTab < 0)
          throw new Error("Invalid Git numstat record.");
        const insertion = field.slice(0, firstTab);
        const deletion = field.slice(firstTab + 1, secondTab);
        if (
          ![insertion, deletion].every(
            (value) => value === "-" || /^\d+$/.test(value),
          )
        )
          throw new Error("Invalid Git numstat counts.");
        statistics.push({
          path: field.slice(secondTab + 1),
          insertions: insertion === "-" ? null : Number(insertion),
          deletions: deletion === "-" ? null : Number(deletion),
        });
      }
      const statuses = new Map<string, string>();
      if (options.files) {
        let status: string | undefined;
        for await (const field of gitFields(
          repository,
          [...flags, "--name-status", "-z", ...trees],
          "",
          0,
        )) {
          if (status === undefined) status = field;
          else {
            statuses.set(field, status);
            status = undefined;
          }
        }
        if (status !== undefined || statuses.size !== statistics.length)
          throw new Error("Incomplete Git file status records.");
      }
      db.exec("BEGIN IMMEDIATE");
      transaction = true;
      db.prepare(`INSERT INTO commit_enrichment VALUES (?, ?, ?, ?, ?, ?, ?, 'complete', NULL, ?)
        ON CONFLICT(repository_id, hash) DO UPDATE SET files_changed=excluded.files_changed,
          insertions=excluded.insertions, deletions=excluded.deletions, binary_files=excluded.binary_files,
          files_complete=max(commit_enrichment.files_complete, excluded.files_complete), state='complete', error=NULL,
          enriched_at=excluded.enriched_at`).run(
        id,
        hash,
        statistics.length,
        statistics.reduce((sum, file) => sum + (file.insertions ?? 0), 0),
        statistics.reduce((sum, file) => sum + (file.deletions ?? 0), 0),
        statistics.filter((file) => file.insertions === null).length,
        Number(options.files ?? false),
        new Date().toISOString(),
      );
      if (options.files) {
        db.prepare(
          "DELETE FROM commit_files WHERE repository_id=? AND hash=?",
        ).run(id, hash);
        const insert = db.prepare(
          "INSERT INTO commit_files VALUES (?, ?, ?, ?, ?, ?)",
        );
        for (const file of statistics) {
          const status = statuses.get(file.path);
          if (!status)
            throw new Error("Git file status does not match numstat path.");
          insert.run(
            id,
            hash,
            file.path,
            status,
            file.insertions,
            file.deletions,
          );
        }
      }
      db.exec("COMMIT");
      transaction = false;
      result.enriched++;
    } catch (error) {
      if (transaction) db.exec("ROLLBACK");
      db.prepare(`INSERT INTO commit_enrichment
        (repository_id, hash, state, error, enriched_at) VALUES (?, ?, 'failed', ?, ?)
        ON CONFLICT(repository_id, hash) DO UPDATE SET state='failed', error=excluded.error, enriched_at=excluded.enriched_at`).run(
        id,
        hash,
        safeError(error),
        new Date().toISOString(),
      );
      result.failures++;
      result.errors.push({ repository, hash, error: safeError(error) });
    }
  }
  return result;
}
