import { statSync } from "node:fs";
import type { DatabaseSync } from "node:sqlite";
import { type CollectionResult, collect, safeError } from "./collector.ts";
import { type DiscoveryConfig, discover, inScope } from "./discovery.ts";

export interface ScanSummary {
  repositoriesDiscovered: number;
  repositoriesScanned: number;
  repositoriesChanged: number;
  commitsAdded: number;
  failures: number;
  durationMs: number;
  databaseBytes: number;
  repositories: ({ path: string } & CollectionResult)[];
  errors: { path: string; error: string }[];
}

export async function scanAll(
  db: DatabaseSync,
  databasePath: string,
  config: DiscoveryConfig,
  full = false,
): Promise<ScanSummary> {
  const clock = performance.now();
  const run = db
    .prepare("INSERT INTO scan_runs(started_at, state) VALUES (?, 'running')")
    .run(new Date().toISOString()).lastInsertRowid;
  const summary: ScanSummary = {
    repositoriesDiscovered: 0,
    repositoriesScanned: 0,
    repositoriesChanged: 0,
    commitsAdded: 0,
    failures: 0,
    durationMs: 0,
    databaseBytes: 0,
    repositories: [],
    errors: [],
  };
  try {
    const discovery = discover(config);
    summary.repositoriesDiscovered = discovery.repositories.length;
    summary.errors.push(...discovery.errors);
    for (const path of discovery.repositories) {
      summary.repositoriesScanned++;
      try {
        const result = await collect(db, path, full);
        summary.repositories.push({ path, ...result });
        if (result.mode !== "unchanged") summary.repositoriesChanged++;
        summary.commitsAdded += result.added;
      } catch (error) {
        summary.errors.push({ path, error: safeError(error) });
      }
    }
    for (const repository of db
      .prepare("SELECT id, path FROM repositories")
      .all()) {
      if (
        typeof repository.path !== "string" ||
        !inScope(repository.path, config) ||
        discovery.repositories.includes(repository.path)
      )
        continue;
      db.exec("BEGIN IMMEDIATE");
      try {
        db.prepare(
          "UPDATE repositories SET scan_state='failed' WHERE id=?",
        ).run(repository.id ?? null);
        db.prepare(
          "UPDATE commits SET reachability='unknown' WHERE repository_id=?",
        ).run(repository.id ?? null);
        db.exec("COMMIT");
      } catch (error) {
        db.exec("ROLLBACK");
        throw error;
      }
      summary.errors.push({
        path: repository.path,
        error:
          "Previously indexed repository was not discovered; retained history is now uncertain.",
      });
    }
    summary.failures = summary.errors.length;
    summary.durationMs = Math.round(performance.now() - clock);
    summary.databaseBytes = statSync(databasePath).size;
    db.prepare(`UPDATE scan_runs SET finished_at=?, state=?, repositories_scanned=?, repositories_changed=?,
      commits_added=?, failures=?, summary_json=? WHERE id=?`).run(
      new Date().toISOString(),
      summary.failures ? "failed" : "complete",
      summary.repositoriesScanned,
      summary.repositoriesChanged,
      summary.commitsAdded,
      summary.failures,
      JSON.stringify(summary),
      run,
    );
    return summary;
  } catch (error) {
    db.prepare(
      "UPDATE scan_runs SET finished_at=?, state='failed', failures=failures+1, summary_json=? WHERE id=?",
    ).run(
      new Date().toISOString(),
      JSON.stringify({ error: safeError(error) }),
      run,
    );
    throw error;
  }
}
