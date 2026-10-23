import { dirname } from "node:path";
import type { SQLInputValue } from "node:sqlite";
import { DatabaseSync } from "node:sqlite";
import { pathToFileURL } from "node:url";
import {
  isMainThread,
  parentPort,
  Worker,
  workerData,
} from "node:worker_threads";

export interface SearchOptions {
  q?: string;
  mode?: string;
  scope?: string;
  kind?: string;
  extension?: string;
  modifiedFrom?: string;
  modifiedTo?: string;
  createdFrom?: string;
  createdTo?: string;
  changedFrom?: string;
  changedTo?: string;
  duplicates?: string;
  hash?: string;
  offset?: string;
}
export function fuzzyScore(query: string, text: string): number {
  const q = query.toLowerCase();
  const t = text.toLowerCase();
  if (!q || t === q) return 0;
  if (t.includes(q)) return 1;
  let pos = 0;
  for (const char of t) if (char === q[pos]) pos++;
  if (pos === q.length) return 2;
  // Bounded edit distance against words: catches typing errors such as 'holidy'.
  if (q.length < 4) return -1;
  for (const word of t.split(/[^\p{L}\p{N}]+/u)) {
    const max = q.length > 7 ? 2 : 1;
    if (Math.abs(word.length - q.length) > max) continue;
    let prev = Array.from({ length: word.length + 1 }, (_, i) => i);
    for (let i = 1; i <= q.length; i++) {
      const next = [i];
      for (let j = 1; j <= word.length; j++)
        next[j] = Math.min(
          (next[j - 1] ?? 0) + 1,
          (prev[j] ?? 0) + 1,
          (prev[j - 1] ?? 0) + (q[i - 1] === word[j - 1] ? 0 : 1),
        );
      prev = next;
      if (Math.min(...next) > max) {
        prev = [];
        break;
      }
    }
    if ((prev[word.length] ?? Infinity) <= max) return 3;
  }
  return -1;
}
export function searchDatabase(
  database: string,
  options: SearchOptions,
): object {
  const db = new DatabaseSync(database, { readOnly: true });
  db.exec("PRAGMA busy_timeout=2000; PRAGMA temp_store=MEMORY; BEGIN");
  try {
    const q = options.q ?? "";
    if (q.length > 200)
      throw Error("Search text must be at most 200 characters.");
    const mode = options.mode ?? "fuzzy";
    if (!["fuzzy", "contains", "exact", "regex"].includes(mode))
      throw Error("Unknown search mode.");
    if (options.scope && !["name", "path"].includes(options.scope))
      throw Error("Unknown search scope.");
    const column = options.scope === "path" ? "e.path" : "e.name";
    const where = ["1=1"];
    const params: SQLInputValue[] = [];
    let score = "0";
    if (q) {
      if (mode === "regex") {
        const regex = new RegExp(q, "iu");
        db.function("matches", (value) => (regex.test(String(value)) ? 1 : 0));
        where.push(`matches(${column})=1`);
      } else if (mode === "fuzzy") {
        const scores = new Map<string, number>();
        db.function("score", (value) => {
          const text = String(value);
          const cached = scores.get(text);
          if (cached !== undefined) return cached;
          const result = fuzzyScore(q, text);
          if (scores.size >= 50000) scores.clear();
          scores.set(text, result);
          return result;
        });
        score = `score(${column})`;
        where.push(`${score}>=0`);
      } else {
        where.push(
          mode === "exact"
            ? `${column}=? COLLATE NOCASE`
            : `instr(lower(${column}),lower(?))>0`,
        );
        params.push(q);
      }
    }
    if (options.kind) {
      if (!["file", "directory", "symlink", "other"].includes(options.kind))
        throw Error("Unknown entry type.");
      where.push("e.kind=?");
      params.push(options.kind);
    }
    if (options.extension) {
      const extensions = options.extension
        .split(",")
        .map((x) => x.trim().replace(/^\./, "").toLowerCase())
        .filter(Boolean);
      if (extensions.length > 30)
        throw Error("Use at most 30 file extensions.");
      if (extensions.length) {
        where.push(`e.extension IN (${extensions.map(() => "?").join(",")})`);
        params.push(...extensions);
      }
    }
    for (const [field, from, to] of [
      ["mtime", options.modifiedFrom, options.modifiedTo],
      ["birthtime", options.createdFrom, options.createdTo],
      ["ctime", options.changedFrom, options.changedTo],
    ] as const) {
      for (const [value, operator, end] of [
        [from, ">=", false],
        [to, "<", true],
      ] as const) {
        if (!value) continue;
        if (!/^\d{4}-\d{2}-\d{2}$/.test(value))
          throw Error("Dates must use YYYY-MM-DD.");
        const date = Date.parse(`${value}T00:00:00Z`);
        if (
          !Number.isFinite(date) ||
          new Date(date).toISOString().slice(0, 10) !== value
        )
          throw Error("Invalid date.");
        where.push(`e.${field}${operator}?`);
        params.push(date + (end ? 86_400_000 : 0));
      }
    }
    if (options.hash) {
      if (!/^[a-f0-9]{64}$/i.test(options.hash))
        throw Error("Invalid SHA-256 hash.");
      where.push("e.hash=?");
      params.push(options.hash.toLowerCase());
    }
    if (options.duplicates === "true")
      where.push(
        "e.hash IS NOT NULL AND EXISTS (SELECT 1 FROM entries d WHERE d.hash=e.hash AND d.id<>e.id)",
      );
    const offset = Number(options.offset ?? 0);
    if (!Number.isSafeInteger(offset) || offset < 0)
      throw Error("Invalid result offset.");
    const filter = where.join(" AND ");
    // Evaluate expensive fuzzy/regexp matching once; keep only matching IDs and scores.
    // TEMP data is private to this read-only connection and never changes the catalogue.
    const expensive = Boolean(q) && (mode === "fuzzy" || mode === "regex");
    if (expensive) {
      db.exec(
        "CREATE TEMP TABLE matches (id INTEGER PRIMARY KEY, score INTEGER NOT NULL)",
      );
      db.prepare(
        `INSERT INTO matches SELECT e.id, ${score} FROM entries e WHERE ${filter}`,
      ).run(...params);
    }
    const total = Number(
      expensive
        ? (db.prepare("SELECT count(*) AS n FROM matches").get()?.n ?? 0)
        : (db
            .prepare(`SELECT count(*) AS n FROM entries e WHERE ${filter}`)
            .get(...params)?.n ?? 0),
    );
    const rows = expensive
      ? db
          .prepare(`SELECT e.*, m.score, (SELECT count(*) FROM entries d WHERE d.hash=e.hash) AS copies
          FROM matches m JOIN entries e ON e.id=m.id ORDER BY m.score, e.name COLLATE NOCASE, e.path LIMIT 100 OFFSET ?`)
          .all(offset)
      : db
          .prepare(`SELECT e.*, 0 AS score, (SELECT count(*) FROM entries d WHERE d.hash=e.hash) AS copies
          FROM entries e WHERE ${filter} ORDER BY e.name COLLATE NOCASE, e.path LIMIT 100 OFFSET ?`)
          .all(...params, offset);
    return {
      total,
      offset,
      limit: 100,
      rows: rows.map((r) => ({
        ...r,
        fileUrl: pathToFileURL(String(r.path)).href,
        folderUrl: pathToFileURL(
          r.kind === "directory" ? String(r.path) : dirname(String(r.path)),
        ).href,
      })),
    };
  } finally {
    db.close();
  }
}
export function search(
  database: string,
  options: SearchOptions,
): Promise<object> {
  return new Promise((resolve, reject) => {
    const worker = new Worker(new URL("./search.ts", import.meta.url), {
      workerData: { database, options },
    });
    const timer = setTimeout(() => {
      void worker.terminate();
      reject(
        Error(
          "Search took too long. Narrow the filters or simplify the regular expression.",
        ),
      );
    }, 8000);
    worker.once("message", (result: { error?: string; data?: object }) => {
      clearTimeout(timer);
      if (result.error) reject(Error(result.error));
      else resolve(result.data ?? {});
    });
    worker.once("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
    worker.once("exit", (code) => {
      clearTimeout(timer);
      if (code !== 0) reject(Error(`Search worker stopped (${code}).`));
    });
  });
}
if (!isMainThread) {
  const { database, options } = workerData as {
    database: string;
    options: SearchOptions;
  };
  try {
    parentPort?.postMessage({ data: searchDatabase(database, options) });
  } catch (error) {
    parentPort?.postMessage({
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
