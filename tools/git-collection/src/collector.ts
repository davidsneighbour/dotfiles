import { randomUUID } from "node:crypto";
import { realpathSync } from "node:fs";
import { basename } from "node:path";
import type { DatabaseSync } from "node:sqlite";
import { git, gitExists, gitFields, snapshot } from "./git.ts";

export interface CollectionResult {
  seen: number;
  added: number;
  mode: "full" | "incremental" | "unchanged";
  durationMs: number;
}

export async function collect(
  db: DatabaseSync,
  suppliedPath: string,
  full = false,
): Promise<CollectionResult> {
  const clock = performance.now();
  const started = new Date().toISOString();
  const run = db
    .prepare(
      "INSERT INTO collection_runs(repository_path, started_at, state) VALUES (?, ?, ?)",
    )
    .run(suppliedPath, started, "running").lastInsertRowid;
  let transaction = false;
  let path = suppliedPath;
  try {
    path = realpathSync(suppliedPath);
    const bare = git(path, ["rev-parse", "--is-bare-repository"]) === "true";
    if (
      !bare &&
      realpathSync(git(path, ["rev-parse", "--show-toplevel"])) !== path
    ) {
      throw new Error("Supply the repository root, not a directory inside it.");
    }
    const format = git(path, ["rev-parse", "--show-object-format"]);
    const shallow =
      git(path, ["rev-parse", "--is-shallow-repository"]) === "true";
    const remotes = git(path, ["remote"])
      .split("\n")
      .filter(Boolean)
      .map((name) => ({
        name,
        urls: git(path, ["remote", "get-url", "--all", name])
          .split("\n")
          .map(redactRemote),
      }));
    const tips = snapshot(path);
    const tipsJson = JSON.stringify(tips);
    db.exec("BEGIN IMMEDIATE");
    transaction = true;
    const existing = db
      .prepare("SELECT * FROM repositories WHERE path = ?")
      .get(path);
    const id = typeof existing?.id === "string" ? existing.id : randomUUID();
    if (existing && existing.object_format !== format)
      throw new Error(
        "Repository object format changed. Rebuild into a new database.",
      );
    // Shallow boundaries can change without moving refs: always rescan shallow histories.
    const previous: string[] =
      existing?.scan_state === "complete" &&
      existing.shallow === 0 &&
      !shallow &&
      typeof existing.tips_json === "string"
        ? parseTips(existing.tips_json)
        : [];
    const mode =
      !full && previous.length && existing?.tips_json === tipsJson
        ? "unchanged"
        : !full &&
            previous.length &&
            previous.every((hash) => gitExists(path, hash))
          ? "incremental"
          : "full";
    db.prepare(`INSERT INTO repositories
      (id, path, name, object_format, remotes_json, shallow, first_seen, last_seen, last_scan, scan_state, tips_json)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, 'pending', NULL)
      ON CONFLICT(path) DO UPDATE SET remotes_json=excluded.remotes_json,
      shallow=excluded.shallow, last_seen=excluded.last_seen, scan_state='pending'`).run(
      id,
      path,
      basename(path),
      format,
      JSON.stringify(remotes),
      Number(shallow),
      started,
      started,
    );
    const insert = db.prepare(`INSERT INTO commits
      (repository_id, hash, author_name, author_email, author_date, committer_name, committer_email,
       committer_date, subject, body, parent_count, collected_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(repository_id, hash) DO NOTHING`);
    let seen = 0;
    let added = 0;
    if (mode !== "unchanged" && tips.length) {
      const revisions =
        [
          ...tips,
          ...(mode === "incremental" ? previous.map((hash) => `^${hash}`) : []),
        ].join("\n") + "\n";
      let fields: string[] = [];
      for await (const field of gitFields(
        path,
        [
          "log",
          "--stdin",
          "--no-show-signature",
          "--encoding=UTF-8",
          "--format=%H%x00%an%x00%ae%x00%aI%x00%cn%x00%ce%x00%cI%x00%s%x00%b%x00%P%x00",
        ],
        revisions,
        0,
      )) {
        fields.push(field);
        if (fields.length !== 10) continue;
        const [
          rawHash,
          author,
          email,
          authorDate,
          committer,
          committerEmail,
          committerDate,
          subject,
          body,
          parents,
        ] = fields;
        const hash = rawHash?.replace(/^\n/, "") ?? "";
        if (
          !new RegExp(
            format === "sha256" ? "^[a-f0-9]{64}$" : "^[a-f0-9]{40}$",
          ).test(hash)
        ) {
          throw new Error("Invalid Git record framing or object hash.");
        }
        added += Number(
          insert.run(
            id,
            hash,
            author ?? "",
            email ?? "",
            authorDate ?? "",
            committer ?? "",
            committerEmail ?? "",
            committerDate ?? "",
            subject ?? "",
            body ?? "",
            parents ? parents.split(" ").length : 0,
            started,
          ).changes,
        );
        seen++;
        fields = [];
      }
      if (fields.length)
        throw new Error("Incomplete Git record; import rolled back.");
    }
    if (mode !== "unchanged") {
      db.exec(
        "CREATE TEMP TABLE IF NOT EXISTS reachable_hashes(hash TEXT PRIMARY KEY) WITHOUT ROWID; DELETE FROM reachable_hashes;",
      );
      const reachable = db.prepare(
        "INSERT OR IGNORE INTO reachable_hashes(hash) VALUES (?)",
      );
      if (tips.length) {
        for await (const hash of gitFields(
          path,
          ["rev-list", "--stdin"],
          tips.join("\n") + "\n",
          10,
        )) {
          reachable.run(hash);
        }
      }
      db.prepare(`UPDATE commits SET reachability=CASE
        WHEN hash IN (SELECT hash FROM reachable_hashes) THEN 'reachable' ELSE ? END WHERE repository_id=?`).run(
        shallow ? "unknown" : "unreachable",
        id,
      );
    }
    if (JSON.stringify(snapshot(path)) !== tipsJson)
      throw new Error(
        "Repository refs changed during collection. Rerun the scan.",
      );
    const finished = new Date().toISOString();
    const durationMs = Math.round(performance.now() - clock);
    db.prepare(
      "UPDATE repositories SET last_scan=?, scan_state='complete', tips_json=? WHERE id=?",
    ).run(finished, tipsJson, id);
    db.prepare(`UPDATE collection_runs SET finished_at=?, state='complete', commits_seen=?, commits_added=?,
      mode=?, duration_ms=? WHERE id=?`).run(
      finished,
      seen,
      added,
      mode,
      durationMs,
      run,
    );
    db.exec("COMMIT");
    transaction = false;
    return { seen, added, mode, durationMs };
  } catch (error) {
    if (transaction) db.exec("ROLLBACK");
    db.exec("BEGIN IMMEDIATE");
    try {
      db.prepare(
        "UPDATE repositories SET scan_state='failed' WHERE path=?",
      ).run(path);
      db.prepare(
        "UPDATE commits SET reachability='unknown' WHERE repository_id IN (SELECT id FROM repositories WHERE path=?)",
      ).run(path);
      db.prepare(
        "UPDATE collection_runs SET finished_at=?, state='failed', error=?, duration_ms=? WHERE id=?",
      ).run(
        new Date().toISOString(),
        safeError(error),
        Math.round(performance.now() - clock),
        run,
      );
      db.exec("COMMIT");
    } catch (recordError) {
      db.exec("ROLLBACK");
      throw new AggregateError(
        [error, recordError],
        "Collection failed and failure recording failed. Check database access.",
      );
    }
    throw new Error(safeError(error));
  }
}

function parseTips(json: string): string[] {
  const value: unknown = JSON.parse(json);
  if (
    !Array.isArray(value) ||
    !value.every(
      (tip: unknown) =>
        typeof tip === "string" && /^[a-f0-9]{40}([a-f0-9]{24})?$/.test(tip),
    )
  ) {
    throw new Error(
      "Invalid stored ref checkpoint. Rebuild into a new database.",
    );
  }
  return value as string[];
}

function redactRemote(remote: string): string {
  return remote
    .replace(/(\w+:\/\/)[^/@\s]+@/g, "$1[redacted]@")
    .replace(/[?#].*$/, "");
}

export function safeError(error: unknown): string {
  return redactRemote(error instanceof Error ? error.message : String(error));
}
