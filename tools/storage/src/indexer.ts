import { createHash, randomUUID } from "node:crypto";
import type { BigIntStats } from "node:fs";
import { constants } from "node:fs";
import { lstat, open, opendir, stat } from "node:fs/promises";
import { basename, extname, join, relative } from "node:path";
import type { Config } from "./core.ts";
import { openDatabase, setMeta, verifyDrive } from "./core.ts";

export interface ScanOptions {
  verbose?: boolean;
  rehash?: boolean;
  metadataOnly?: boolean;
  signal?: AbortSignal;
}
const message = (e: unknown): string =>
  e instanceof Error ? e.message : String(e);
const signature = (s: BigIntStats): string =>
  `${s.dev}:${s.ino}:${s.size}:${s.mtimeNs}:${s.ctimeNs}`;
export async function indexDrive(
  config: Config,
  options: ScanOptions = {},
): Promise<number> {
  // flock is held by the CLI wrapper; API callers/tests must also serialise writers.
  const identity = await verifyDrive(config);
  const db = await openDatabase(config);
  try {
    const run = randomUUID();
    setMeta(db, "scanStarted", new Date().toISOString());
    setMeta(db, "phase", "Scanning names and paths");
    let errors = 0;
    let count = 0;
    const previous = db.prepare("SELECT * FROM entries WHERE path=?");
    const insert =
      db.prepare(`INSERT INTO entries(path,name,kind,extension,size,mtime,ctime,birthtime,dev,ino,fingerprint,hash,error,seen)
      VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(path) DO UPDATE SET name=excluded.name,kind=excluded.kind,
      extension=excluded.extension,size=excluded.size,mtime=excluded.mtime,ctime=excluded.ctime,birthtime=excluded.birthtime,
      dev=excluded.dev,ino=excluded.ino,fingerprint=excluded.fingerprint,hash=excluded.hash,error=excluded.error,seen=excluded.seen`);
    async function walk(path: string): Promise<void> {
      options.signal?.throwIfAborted();
      const rel = relative(config.root, path);
      if (config.exclude.some((p) => rel === p || rel.startsWith(`${p}/`)))
        return;
      if (basename(path) === "scratch") return;
      try {
        const s = await lstat(path, { bigint: true });
        if (String(s.dev) !== identity.split(":")[0]) {
          console.error(`Skipped nested filesystem: ${path}`);
          return;
        }
        const kind = s.isDirectory()
          ? "directory"
          : s.isFile()
            ? "file"
            : s.isSymbolicLink()
              ? "symlink"
              : "other";
        const old = previous.get(path);
        const unchanged =
          old && old.kind === kind && old.fingerprint === signature(s);
        insert.run(
          path,
          basename(path),
          kind,
          kind === "file" ? extname(path).slice(1).toLowerCase() : "",
          Number(s.size),
          Number(s.mtimeNs) / 1e6,
          Number(s.ctimeNs) / 1e6,
          s.birthtimeNs > 0 ? Number(s.birthtimeNs) / 1e6 : null,
          String(s.dev),
          String(s.ino),
          signature(s),
          unchanged && !options.rehash ? (old.hash ?? null) : null,
          null,
          run,
        );
        count++;
        if (count % 5000 === 0) {
          setMeta(db, "scanEntries", String(count));
          console.log(`Scanned ${count} entries`);
        }
        if (kind === "directory") {
          const dir = await opendir(path);
          for await (const child of dir) await walk(join(path, child.name));
        }
      } catch (error) {
        options.signal?.throwIfAborted();
        errors++;
        console.error(`Cannot index ${path}: ${message(error)}`);
        db.prepare("UPDATE entries SET error=? WHERE path=?").run(
          message(error),
          path,
        );
      }
    }
    await walk(config.root);
    options.signal?.throwIfAborted();
    if ((await verifyDrive(config)) !== identity)
      throw Error("Drive changed during scan; old entries retained.");
    // A single traversal error prevents pruning, including descendants of unreadable directories.
    if (errors === 0) db.prepare("DELETE FROM entries WHERE seen<>?").run(run);
    setMeta(db, "scanFinished", new Date().toISOString());
    setMeta(db, "scanErrors", String(errors));
    setMeta(db, "scanEntries", String(count));
    console.log(`Names indexed: ${count}; scan errors: ${errors}.`);
    if (options.metadataOnly) {
      setMeta(db, "phase", "Metadata indexed; hashes pending");
      return errors;
    }
    setMeta(db, "phase", "Hashing files");
    const deadline = Date.now() + config.hashBudgetMinutes * 60_000;
    let hashed = 0;
    let hashErrors = 0;
    // Keyset batches keep memory bounded and release read statements before each write.
    let lastId = 0;
    while (Date.now() < deadline) {
      const rows = db
        .prepare(
          "SELECT * FROM entries WHERE id>? AND kind='file' AND hash IS NULL AND seen=? ORDER BY id LIMIT 100",
        )
        .all(lastId, run);
      if (rows.length === 0) break;
      for (const row of rows) {
        if (Date.now() >= deadline) break;
        options.signal?.throwIfAborted();
        lastId = Number(row.id);
        const path = String(row.path);
        let file;
        try {
          const rootStat = await stat(config.root);
          if (`${rootStat.dev}:${rootStat.ino}` !== identity)
            throw Error("Storage drive changed.");
          file = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW);
          const before = await file.stat({ bigint: true });
          if (!before.isFile() || signature(before) !== row.fingerprint)
            throw Error("File changed since scan; retry on next update.");
          const hash = createHash("sha256");
          const stream = file.createReadStream({
            autoClose: false,
            highWaterMark: 1024 * 1024,
            signal: options.signal,
          });
          for await (const chunk of stream) hash.update(chunk);
          const after = await file.stat({ bigint: true });
          const current = await stat(path, { bigint: true });
          if (
            signature(before) !== signature(after) ||
            signature(after) !== signature(current)
          )
            throw Error("File changed while hashing; retry on next update.");
          db.prepare("UPDATE entries SET hash=?,error=NULL WHERE id=?").run(
            hash.digest("hex"),
            Number(row.id),
          );
          hashed++;
          if (options.verbose || hashed % 1000 === 0)
            console.log(`Hashed ${hashed}: ${path}`);
          setMeta(db, "hashLastPath", path);
        } catch (error) {
          options.signal?.throwIfAborted();
          hashErrors++;
          console.error(`Cannot hash ${path}: ${message(error)}`);
          db.prepare("UPDATE entries SET hash=NULL,error=? WHERE id=?").run(
            message(error),
            Number(row.id),
          );
        } finally {
          await file?.close();
        }
      }
    }
    setMeta(
      db,
      "phase",
      errors + hashErrors > 0 ? "Idle; update has errors (see log)" : "Idle",
    );
    setMeta(db, "updateFinished", new Date().toISOString());
    console.log(
      `Update finished; ${hashed} hashes calculated; ${errors + hashErrors} errors. Pending files resume on the next update.`,
    );
    return errors + hashErrors;
  } catch (error) {
    setMeta(db, "phase", `Interrupted: ${message(error)}`);
    throw error;
  } finally {
    db.close();
  }
}
