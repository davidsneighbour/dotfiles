import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { DatabaseSync } from "node:sqlite";
import { test } from "node:test";
import { collect as collectRepository } from "../src/collector.ts";
import { openDatabase, verifyDatabase } from "../src/database.ts";
import { search } from "../src/query.ts";

async function collect(
  db: DatabaseSync,
  path: string,
): Promise<{ seen: number; added: number }> {
  const { seen, added } = await collectRepository(db, path, true);
  return { seen, added };
}

test("real Git history, idempotence, detached HEAD, bare clone, and failed scans", async () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-"));
  const repository = join(root, "repo");
  const git = (...args: string[]): string =>
    execFileSync("git", ["-C", repository, ...args], {
      encoding: "utf8",
    }).trim();
  const db = openDatabase(join(root, "catalogue.sqlite"), true);
  try {
    execFileSync("git", ["init", "--initial-branch=main", repository]);
    git("config", "core.hooksPath", "/dev/null");
    git("config", "commit.gpgsign", "false");
    git("config", "user.name", 'Zoë "Example"');
    git("config", "user.email", "zoe@example.invalid");
    git(
      "commit",
      "--allow-empty",
      "-m",
      "First 🎉",
      "-m",
      "Line one\n\nLine two\u001e separator",
    );
    git("checkout", "-b", "feature");
    git("commit", "--allow-empty", "-m", "Feature");
    git("checkout", "main");
    git("commit", "--allow-empty", "-m", "Main");
    git("merge", "--no-ff", "feature", "-m", "Merge");
    const first = await collect(db, repository);
    assert.deepEqual(first, { seen: 4, added: 4 });
    const before = db.prepare("SELECT * FROM commits ORDER BY hash").all();
    assert.deepEqual(await collect(db, repository), { seen: 4, added: 0 });
    assert.deepEqual(
      db.prepare("SELECT * FROM commits ORDER BY hash").all(),
      before,
    );
    assert.equal(
      db.prepare("SELECT max(parent_count) AS count FROM commits").get()?.count,
      2,
    );
    assert.equal(
      db.prepare("SELECT body FROM commits WHERE subject=?").get("First 🎉")
        ?.body,
      "Line one\n\nLine two\u001e separator\n",
    );
    git("checkout", "--detach");
    git("commit", "--allow-empty", "-m", "Detached");
    assert.deepEqual(await collect(db, repository), { seen: 5, added: 1 });
    const bare = join(root, "bare.git");
    execFileSync("git", ["clone", "--bare", repository, bare], {
      stdio: "pipe",
    });
    assert.equal((await collect(db, bare)).seen, 5);
    await assert.rejects(collect(db, join(root, "missing")));
    assert.equal(
      db
        .prepare(
          "SELECT count(*) AS count FROM collection_runs WHERE state='failed'",
        )
        .get()?.count,
      1,
    );
    verifyDatabase(db);
  } finally {
    db.close();
    rmSync(root, { recursive: true, force: true });
  }
});

test("initialise, reopen read-only, reject future schema, and recreate", () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-"));
  const path = join(root, "db.sqlite");
  try {
    const db = openDatabase(path, true);
    verifyDatabase(db);
    db.close();
    const reader = openDatabase(path);
    assert.equal(
      reader.prepare("SELECT count(*) AS count FROM commits").get()?.count,
      0,
    );
    reader.close();
    const writer = openDatabase(path, true);
    writer.exec("PRAGMA user_version=99");
    writer.close();
    assert.throws(() => openDatabase(path, true), /Unsupported schema/);
    rmSync(path);
    const recreated = openDatabase(path, true);
    verifyDatabase(recreated);
    recreated.close();
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("empty and SHA-256 repositories", async () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-"));
  const repository = join(root, "repo");
  const db = openDatabase(join(root, "db.sqlite"), true);
  try {
    execFileSync("git", [
      "init",
      "--object-format=sha256",
      "--initial-branch=main",
      repository,
    ]);
    assert.deepEqual(await collect(db, repository), { seen: 0, added: 0 });
    execFileSync("git", [
      "-C",
      repository,
      "-c",
      "core.hooksPath=/dev/null",
      "-c",
      "commit.gpgsign=false",
      "-c",
      "user.name=Test",
      "-c",
      "user.email=test@example.invalid",
      "commit",
      "--allow-empty",
      "-m",
      "SHA-256",
    ]);
    assert.deepEqual(await collect(db, repository), { seen: 1, added: 1 });
    assert.equal(
      String(db.prepare("SELECT hash FROM commits").get()?.hash).length,
      64,
    );
  } finally {
    db.close();
    rmSync(root, { recursive: true, force: true });
  }
});

test("substantial history streams correctly and write failures roll back all commits", async (context) => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-"));
  const repository = join(root, "repo");
  const db = openDatabase(join(root, "db.sqlite"), true);
  try {
    execFileSync("git", ["init", "--initial-branch=main", repository]);
    let input = "";
    for (let index = 1; index <= 100000; index++) {
      const message = `Commit ${index}\n`;
      input += `commit refs/heads/main\nmark :${index}\ncommitter Test <test@example.invalid> ${1700000000 + index} +0700\ndata ${Buffer.byteLength(message)}\n${message}${index > 1 ? `from :${index - 1}\n` : ""}\n`;
    }
    execFileSync("git", ["-C", repository, "fast-import", "--quiet"], {
      input,
      stdio: ["pipe", "pipe", "pipe"],
    });
    db.exec(`CREATE TRIGGER reject_commit BEFORE INSERT ON commits WHEN NEW.subject='Commit 5000'
      BEGIN SELECT RAISE(ABORT, 'simulated interrupted write'); END;`);
    await assert.rejects(
      collect(db, repository),
      /simulated interrupted write/,
    );
    assert.equal(
      db.prepare("SELECT count(*) AS count FROM commits").get()?.count,
      0,
    );
    assert.equal(
      db.prepare("SELECT count(*) AS count FROM repositories").get()?.count,
      0,
    );
    db.exec("DROP TRIGGER reject_commit");
    const initial = await collectRepository(db, repository, true);
    assert.deepEqual(
      { seen: initial.seen, added: initial.added },
      {
        seen: 100000,
        added: 100000,
      },
    );
    assert.deepEqual(await collect(db, repository), { seen: 100000, added: 0 });
    const unchanged = await collectRepository(db, repository);
    assert.equal(unchanged.mode, "unchanged");
    assert.equal(unchanged.seen, 0);
    const searchStarted = performance.now();
    assert.equal(search(db, { query: '"Commit 50000"' }).length, 1);
    const searchMs = Number((performance.now() - searchStarted).toFixed(2));
    context.diagnostic(
      JSON.stringify({
        commits: 100000,
        initialImportMs: initial.durationMs,
        unchangedScanMs: unchanged.durationMs,
        phraseSearchMs: searchMs,
        databaseBytes: statSync(join(root, "db.sqlite")).size,
      }),
    );
    verifyDatabase(db);
  } finally {
    db.close();
    rmSync(root, { recursive: true, force: true });
  }
});
