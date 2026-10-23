import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  chmod,
  mkdir,
  mkdtemp,
  rename,
  rm,
  symlink,
  unlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { test } from "node:test";
import type { Config } from "../src/core.ts";
import { loadConfig, verifyDrive } from "../src/core.ts";
import { indexDrive } from "../src/indexer.ts";
import { search, searchDatabase } from "../src/search.ts";
import { serve } from "../src/server.ts";

test("catalogue, incremental hashes, all occurrences, filters, removals, and offline safety", async () => {
  const temp = await mkdtemp(join(tmpdir(), "storage-test-"));
  const root = join(temp, "drive");
  await mkdir(root);
  const config: Config = {
    root,
    database: join(temp, "state/catalogue.sqlite"),
    port: 18765,
    mountUuid: null,
    exclude: ["excluded"],
    hashBudgetMinutes: 1,
  };
  const query = (options: Parameters<typeof searchDatabase>[1]) =>
    searchDatabase(config.database, options) as {
      total: number;
      rows: {
        id: number;
        hash: string | null;
        path: string;
        kind: string;
        error: string | null;
      }[];
    };
  try {
    await mkdir(join(root, "backup"));
    await mkdir(join(root, "excluded"));
    await mkdir(join(root, "scratch"));
    await writeFile(join(root, "Holiday photo.JPG"), "same content");
    await writeFile(join(root, "backup/Holiday photo.JPG"), "same content");
    await writeFile(join(root, "excluded/hidden.txt"), "excluded");
    await writeFile(
      join(root, "scratch/hidden.txt"),
      "excluded by repository policy",
    );
    await writeFile(join(root, "<unsafe>.txt"), "different");
    await symlink("/etc/passwd", join(root, "outside-link"));
    await indexDrive(config, { metadataOnly: true });
    assert.equal(query({ q: "Holiday photo.JPG", mode: "exact" }).total, 2);
    assert.equal(query({ q: "Holiday", mode: "contains" }).rows[0]?.hash, null);
    await indexDrive(config);
    const expectedHash = createHash("sha256")
      .update("same content")
      .digest("hex");
    assert.equal(query({ hash: expectedHash }).total, 2);
    assert.equal(query({ q: "holidy" }).total, 2);
    assert.equal(
      query({ q: "^holiday.*jpg$", mode: "regex", extension: ".jpg" }).total,
      2,
    );
    assert.equal(query({ q: "holiday", kind: "directory" }).total, 0);
    assert.equal(query({ duplicates: "true" }).total, 2);
    assert.equal(query({ q: "hidden" }).total, 0);
    assert.equal(query({ kind: "symlink" }).rows[0]?.hash, null);
    assert.equal(query({ modifiedFrom: "2100-01-01" }).total, 0);
    assert.throws(() => query({ q: "[", mode: "regex" }));
    assert.throws(() => query({ createdFrom: "2026-02-31" }));
    assert.throws(() => query({ offset: "-1" }));
    await assert.rejects(verifyDrive({ ...config, mountUuid: "wrong-drive" }));
    const db = new DatabaseSync(config.database);
    db.exec(
      `CREATE TRIGGER no_rehash BEFORE UPDATE OF hash ON entries WHEN old.hash IS NOT NULL AND new.hash IS NOT old.hash BEGIN SELECT RAISE(FAIL,'unexpected rehash'); END`,
    );
    db.close();
    await indexDrive(config);
    assert.equal(query({ hash: expectedHash }).total, 2);
    const dropTrigger = new DatabaseSync(config.database);
    dropTrigger.exec("DROP TRIGGER no_rehash");
    dropTrigger.close();
    // A changed file invalidates its old content hash.
    const before = query({ q: "Holiday photo.JPG", mode: "exact" });
    assert.equal(before.rows.length, 2);
    await writeFile(join(root, "Holiday photo.JPG"), "new! content");
    await indexDrive(config);
    assert.equal(query({ hash: expectedHash }).total, 1);
    await rename(
      join(root, "backup/Holiday photo.JPG"),
      join(root, "backup/renamed.jpg"),
    );
    await unlink(join(root, "<unsafe>.txt"));
    await indexDrive(config);
    assert.equal(query({ q: "<unsafe>", mode: "contains" }).total, 0);
    assert.equal(query({ q: "renamed" }).total, 1);
    const indexed = query({}).total;
    await rename(root, `${root}-offline`);
    await assert.rejects(indexDrive(config));
    assert.equal(query({}).total, indexed);
    const worker = (await search(config.database, { q: "renamed" })) as {
      total: number;
    };
    assert.equal(worker.total, 1);
    const server = await serve(config);
    try {
      const s = (await (
        await fetch(`http://127.0.0.1:${config.port}/api/status`)
      ).json()) as { online: boolean };
      assert.equal(s.online, false);
      const html = await fetch(`http://127.0.0.1:${config.port}/`);
      assert.equal(html.status, 200);
      const blocked = await fetch(
        `http://127.0.0.1:${config.port}/api/open?id=1`,
        { method: "POST" },
      );
      assert.equal(blocked.status, 400);
      const badRegex = await fetch(
        `http://127.0.0.1:${config.port}/api/search?mode=regex&q=%5B`,
      );
      assert.equal(badRegex.status, 400);
    } finally {
      await new Promise<void>((resolve, reject) =>
        server.close((error) => (error ? reject(error) : resolve())),
      );
    }
    await rename(`${root}-offline`, root);
    await assert.rejects(
      loadConfig(
        await (async () => {
          const p = join(temp, "bad.json");
          await writeFile(
            p,
            JSON.stringify({ ...config, database: join(root, "bad.sqlite") }),
          );
          return p;
        })(),
      ),
    );
  } finally {
    await rm(temp, { recursive: true, force: true });
  }
});

test("interrupted scan retains entries and pending hashes can resume", async () => {
  const temp = await mkdtemp(join(tmpdir(), "storage-abort-"));
  const root = join(temp, "drive");
  await mkdir(root);
  const config: Config = {
    root,
    database: join(temp, "db.sqlite"),
    port: 18766,
    mountUuid: null,
    exclude: [],
    hashBudgetMinutes: 1,
  };
  try {
    await writeFile(join(root, "retain.txt"), "retain");
    await indexDrive(config, { metadataOnly: true });
    const controller = new AbortController();
    controller.abort();
    await assert.rejects(indexDrive(config, { signal: controller.signal }));
    const db = new DatabaseSync(config.database);
    assert.equal(db.prepare("SELECT count(*) n FROM entries").get()?.n, 2);
    db.close();
    await indexDrive(config);
    const result = searchDatabase(config.database, {
      q: "retain.txt",
      mode: "exact",
    }) as { rows: { hash: string | null }[] };
    assert.ok(result.rows[0]?.hash);
  } finally {
    await rm(temp, { recursive: true, force: true });
  }
});

test("pagination lists every occurrence and date bounds include the final day", async () => {
  const temp = await mkdtemp(join(tmpdir(), "storage-pages-"));
  const config: Config = {
    root: join(temp, "drive"),
    database: join(temp, "db.sqlite"),
    port: 18767,
    mountUuid: null,
    exclude: [],
    hashBudgetMinutes: 1,
  };
  try {
    const { openDatabase } = await import("../src/core.ts");
    const db = await openDatabase(config);
    const insert = db.prepare(
      `INSERT INTO entries(path,name,kind,extension,size,mtime,ctime,birthtime,dev,ino,fingerprint,hash,error,seen) VALUES (?,?,'file','pdf',1,?,?,?,'1','1','test',NULL,NULL,'test')`,
    );
    const day = Date.parse("2026-10-22T23:59:59Z");
    db.exec("BEGIN");
    for (let i = 0; i < 205; i++)
      insert.run(
        join(config.root, `invoice-${i}.pdf`),
        `invoice-${i}.pdf`,
        day,
        day,
        day,
      );
    db.exec("COMMIT");
    db.close();
    const first = searchDatabase(config.database, {
      q: "invoice",
      modifiedFrom: "2026-10-22",
      modifiedTo: "2026-10-22",
    }) as { total: number; rows: { id: number }[] };
    const second = searchDatabase(config.database, {
      q: "invoice",
      offset: "100",
    }) as typeof first;
    const third = searchDatabase(config.database, {
      q: "invoice",
      offset: "200",
    }) as typeof first;
    assert.equal(first.total, 205);
    assert.equal(first.rows.length, 100);
    assert.equal(second.rows.length, 100);
    assert.equal(third.rows.length, 5);
    assert.equal(
      new Set([...first.rows, ...second.rows, ...third.rows].map((r) => r.id))
        .size,
      205,
    );
    assert.equal(
      (
        searchDatabase(config.database, {
          createdTo: "2026-10-21",
        }) as typeof first
      ).total,
      0,
    );
    assert.equal(
      (
        searchDatabase(config.database, {
          changedFrom: "2026-10-23",
        }) as typeof first
      ).total,
      0,
    );
  } finally {
    await rm(temp, { recursive: true, force: true });
  }
});

test("a pathological regular expression is terminated within the query time limit", async () => {
  const temp = await mkdtemp(join(tmpdir(), "storage-regex-"));
  const config: Config = {
    root: join(temp, "drive"),
    database: join(temp, "db.sqlite"),
    port: 18768,
    mountUuid: null,
    exclude: [],
    hashBudgetMinutes: 1,
  };
  try {
    const { openDatabase } = await import("../src/core.ts");
    const db = await openDatabase(config);
    db.prepare(
      `INSERT INTO entries(path,name,kind,extension,size,mtime,ctime,birthtime,dev,ino,fingerprint,hash,error,seen) VALUES (?,?,'file','',0,0,0,NULL,'1','1','test',NULL,NULL,'test')`,
    ).run(join(config.root, "test"), `${"a".repeat(120)}!`);
    db.close();
    await assert.rejects(
      search(config.database, { q: "(a+)+$", mode: "regex" }),
      /Search took too long/,
    );
    const result = (await search(config.database, {
      q: "aaaa",
      mode: "contains",
    })) as { total: number };
    assert.equal(result.total, 1);
  } finally {
    await rm(temp, { recursive: true, force: true });
  }
});

test("an unreadable directory prevents pruning of old catalogue paths", async (t) => {
  if (process.getuid?.() === 0) {
    t.skip("Permission fixture requires a non-root user.");
    return;
  }
  const temp = await mkdtemp(join(tmpdir(), "storage-unreadable-"));
  const root = join(temp, "drive");
  const blocked = join(root, "blocked");
  await mkdir(blocked, { recursive: true });
  const config: Config = {
    root,
    database: join(temp, "db.sqlite"),
    port: 18769,
    mountUuid: null,
    exclude: [],
    hashBudgetMinutes: 1,
  };
  try {
    await writeFile(join(blocked, "retain.txt"), "retain");
    await writeFile(join(root, "removed.txt"), "removed");
    await indexDrive(config, { metadataOnly: true });
    await unlink(join(root, "removed.txt"));
    await chmod(blocked, 0);
    assert.equal(await indexDrive(config, { metadataOnly: true }), 1);
    const retained = searchDatabase(config.database, {
      q: ".txt",
      mode: "contains",
    }) as { total: number };
    assert.equal(retained.total, 2);
    await chmod(blocked, 0o700);
    assert.equal(await indexDrive(config, { metadataOnly: true }), 0);
    assert.equal(
      (
        searchDatabase(config.database, { q: ".txt", mode: "contains" }) as {
          total: number;
        }
      ).total,
      1,
    );
  } finally {
    await chmod(blocked, 0o700);
    await rm(temp, { recursive: true, force: true });
  }
});
