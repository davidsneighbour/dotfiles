import type { DatabaseSync } from "node:sqlite";

export interface SearchOptions {
  query: string;
  repository?: string;
  author?: string;
  since?: string;
  until?: string;
  limit?: number;
}

export function search(
  db: DatabaseSync,
  options: SearchOptions,
): Record<string, unknown>[] {
  if (!options.query.trim())
    throw new Error("Search requires a non-empty --query.");
  const limit = options.limit ?? 50;
  if (!Number.isInteger(limit) || limit < 1 || limit > 1000)
    throw new Error("--limit must be from 1 to 1000.");
  for (const date of [options.since, options.until]) {
    const parsed = date ? new Date(`${date}T00:00:00Z`) : undefined;
    if (
      date !== undefined &&
      (!/^\d{4}-\d{2}-\d{2}$/.test(date) ||
        !parsed ||
        !Number.isFinite(parsed.getTime()) ||
        parsed.toISOString().slice(0, 10) !== date)
    ) {
      throw new Error("Date filters require valid YYYY-MM-DD dates.");
    }
  }
  if (options.since && options.until && options.since > options.until)
    throw new Error("--since must be on or before --until.");
  return db
    .prepare(`SELECT c.*, r.name AS repository, bm25(commit_search) AS rank
    FROM commit_search JOIN commits c ON c.rowid=commit_search.rowid
    JOIN repositories r ON r.id=c.repository_id
    WHERE commit_search MATCH ? AND (? IS NULL OR r.id=? OR r.name=? OR r.path=?)
      AND (? IS NULL OR c.author_email=?)
      AND (? IS NULL OR date(c.committer_date, '+7 hours')>=?)
      AND (? IS NULL OR date(c.committer_date, '+7 hours')<=?)
    ORDER BY rank, unixepoch(c.committer_date) DESC, c.hash LIMIT ?`)
    .all(
      options.query,
      options.repository ?? null,
      options.repository ?? null,
      options.repository ?? null,
      options.repository ?? null,
      options.author ?? null,
      options.author ?? null,
      options.since ?? null,
      options.since ?? null,
      options.until ?? null,
      options.until ?? null,
      limit,
    );
}
