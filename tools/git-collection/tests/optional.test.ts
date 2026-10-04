import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { test } from "node:test";
import { collect } from "../src/collector.ts";
import { openDatabase, verifyDatabase } from "../src/database.ts";
import { enrich } from "../src/enrichment.ts";
import { search } from "../src/query.ts";
import { generateReports } from "../src/reports.ts";

function git(path: string, ...args: string[]): string {
  return execFileSync("git", ["-C", path, ...args], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

test("enrichment is resumable, supports unusual paths and binary files, and keeps failures outside collection", async () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-enrichment-"));
  const repository = join(root, "repo");
  const db = openDatabase(join(root, "db.sqlite"), true);
  try {
    execFileSync("git", ["init", "--initial-branch=main", repository], {
      stdio: "pipe",
    });
    for (const [key, value] of [
      ["user.name", "Example"],
      ["user.email", "example@example.invalid"],
      ["core.hooksPath", "/dev/null"],
      ["commit.gpgsign", "false"],
    ])
      git(repository, "config", key ?? "", value ?? "");
    const name = "file\twith\nUnicode-字.txt";
    writeFileSync(join(repository, name), "one\ntwo\n");
    writeFileSync(join(repository, "binary.bin"), Buffer.from([0, 1, 2]));
    git(repository, "add", "--all");
    git(repository, "commit", "-m", "Initial files");
    const first = git(repository, "rev-parse", "HEAD");
    writeFileSync(join(repository, name), "one\nthree\nfour\n");
    git(repository, "add", "--all");
    git(repository, "commit", "-m", "Edit file");
    await collect(db, repository);
    assert.equal((await enrich(db, { limit: 1 })).enriched, 1);
    assert.equal((await enrich(db, {})).enriched, 1);
    assert.equal((await enrich(db, {})).enriched, 0);
    assert.equal(
      db
        .prepare("SELECT files_changed FROM commit_enrichment WHERE hash=?")
        .get(first)?.files_changed,
      2,
    );
    assert.equal(
      db
        .prepare("SELECT binary_files FROM commit_enrichment WHERE hash=?")
        .get(first)?.binary_files,
      1,
    );
    assert.equal((await enrich(db, { files: true })).enriched, 2);
    assert.equal(
      db.prepare("SELECT path FROM commit_files WHERE path=? LIMIT 1").get(name)
        ?.path,
      name,
    );
    assert.equal(
      db
        .prepare("SELECT insertions FROM commit_files WHERE path='binary.bin'")
        .get()?.insertions,
      null,
    );
    assert.equal((await enrich(db, { files: true })).enriched, 0);
    git(repository, "commit", "--allow-empty", "-m", "Empty");
    await collect(db, repository);
    rmSync(repository, { recursive: true });
    const failed = await enrich(db, {});
    assert.equal(failed.failures, 1);
    assert.equal(db.prepare("SELECT count(*) AS n FROM commits").get()?.n, 3);
    assert.equal(search(db, { query: "Empty" }).length, 1);
    verifyDatabase(db);
  } finally {
    db.close();
    rmSync(root, { recursive: true, force: true });
  }
});

test("reports regenerate identically, use Bangkok dates and ISO weeks, clean stale owned files, and protect other files", () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-reports-"));
  const db = openDatabase(join(root, "db.sqlite"), true);
  try {
    const id = "00000000-0000-4000-8000-000000000001";
    db.prepare(`INSERT INTO repositories
      (id,path,name,object_format,remotes_json,shallow,first_seen,last_seen,scan_state)
      VALUES (?,?,'Example','sha1','[]',0,'2026-01-01','2026-01-01','complete')`).run(
      id,
      root,
    );
    db.prepare(`INSERT INTO commits
      (repository_id, hash, author_name, author_email, author_date, committer_name, committer_email,
      committer_date, subject, body, parent_count, collected_at)
      VALUES (?, ?, 'Example', 'example@example.invalid', '2026-10-02T18:30:00Z', 'Example',
      'example@example.invalid', '2026-10-02T18:30:00Z', '<script> [subject] **bold**', '', 0, '2026-10-03')`).run(
      id,
      "a".repeat(40),
    );
    const output = join(root, "reports");
    assert.deepEqual(generateReports(db, output), { files: 4, removed: 0 });
    const day = join(output, "daily", "2026-10-03.md");
    const first = readFileSync(day, "utf8");
    assert.match(first, /&lt;script&gt;/);
    assert.match(
      readFileSync(join(output, "weekly", "2026-W40.md"), "utf8"),
      /Commits: 1/,
    );
    assert.deepEqual(generateReports(db, output), { files: 4, removed: 0 });
    assert.equal(readFileSync(day, "utf8"), first);
    const addExample = db.prepare(`INSERT INTO commits
      (repository_id, hash, author_name, author_email, author_date, committer_name,
       committer_email, committer_date, subject, body, parent_count, collected_at)
      SELECT repository_id, ?, author_name, author_email, author_date, committer_name,
       committer_email, committer_date, ?, body, parent_count, collected_at
      FROM commits WHERE hash=?`);
    for (let index = 0; index < 25; index++) {
      addExample.run(
        index.toString(16).padStart(40, "0"),
        `rank-${index}`,
        "a".repeat(40),
      );
    }
    generateReports(db, output);
    for (const file of [
      day,
      join(output, "weekly", "2026-W40.md"),
      join(output, "monthly", "2026-10.md"),
      join(output, "repositories", `${id}.md`),
    ]) {
      const report = readFileSync(file, "utf8");
      assert.match(report, /Commits: 26/);
      const examples = report
        .split("\n")
        .filter((line) => line.startsWith("* "));
      assert.equal(examples.length, 20);
      assert.match(examples[0] ?? "", /rank-0 /);
      assert.match(examples[19] ?? "", /rank-19 /);
    }
    writeFileSync(join(output, "personal.md"), "Keep this");
    db.prepare("UPDATE commits SET committer_date=?").run(
      "2026-10-04T18:30:00Z",
    );
    assert.deepEqual(generateReports(db, output), { files: 4, removed: 2 });
    assert.throws(() => readFileSync(day), /ENOENT/);
    assert.equal(
      readFileSync(join(output, "personal.md"), "utf8"),
      "Keep this",
    );
    writeFileSync(join(output, "daily", "2026-10-05.md"), "Personal content");
    assert.throws(() => generateReports(db, output), /unrecognised/);
    const linked = join(root, "linked");
    symlinkSync(output, linked);
    assert.throws(() => generateReports(db, linked), /symlink/);
  } finally {
    db.close();
    rmSync(root, { recursive: true, force: true });
  }
});

test("version 1 database migrates without losing existing commits or their searchability", () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-migration-"));
  const path = join(root, "db.sqlite");
  try {
    const old = new DatabaseSync(path);
    old.exec(`CREATE TABLE repositories (id TEXT PRIMARY KEY, path TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
      object_format TEXT NOT NULL, remotes_json TEXT NOT NULL, shallow INTEGER NOT NULL,
      first_seen TEXT NOT NULL, last_seen TEXT NOT NULL, last_scan TEXT, scan_state TEXT NOT NULL) STRICT;
      CREATE TABLE commits (repository_id TEXT NOT NULL REFERENCES repositories(id), hash TEXT NOT NULL,
        author_name TEXT NOT NULL, author_email TEXT NOT NULL, author_date TEXT NOT NULL,
        committer_name TEXT NOT NULL, committer_email TEXT NOT NULL, committer_date TEXT NOT NULL,
        subject TEXT NOT NULL, body TEXT NOT NULL, parent_count INTEGER NOT NULL, collected_at TEXT NOT NULL,
        PRIMARY KEY(repository_id,hash)) STRICT;
      CREATE TABLE collection_runs (id INTEGER PRIMARY KEY, repository_path TEXT NOT NULL,
        started_at TEXT NOT NULL, finished_at TEXT, state TEXT NOT NULL, commits_seen INTEGER NOT NULL DEFAULT 0,
        commits_added INTEGER NOT NULL DEFAULT 0, error TEXT) STRICT;
      INSERT INTO repositories VALUES ('legacy', '/old', 'Legacy', 'sha1', '[]', 0, '2026-01-01', '2026-01-01', NULL, 'complete');
      INSERT INTO commits VALUES ('legacy', '${"a".repeat(40)}', 'Example', 'example@example.invalid',
        '2026-01-01', 'Example', 'example@example.invalid', '2026-01-01', 'Migration preserved', '', 0, '2026-01-01');
      PRAGMA user_version=1;`);
    old.close();
    assert.throws(() => openDatabase(path), /upgrade/);
    const migrated = openDatabase(path, true);
    try {
      assert.equal(
        migrated.prepare("PRAGMA user_version").get()?.user_version,
        3,
      );
      assert.equal(search(migrated, { query: "Migration" }).length, 1);
      assert.equal(
        migrated.prepare("SELECT reachability FROM commits").get()
          ?.reachability,
        "unknown",
      );
      verifyDatabase(migrated);
    } finally {
      migrated.close();
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("merge enrichment uses the first parent and records renames as deletion and addition", async () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-merge-statistics-"));
  const repository = join(root, "repo");
  const db = openDatabase(join(root, "db.sqlite"), true);
  try {
    execFileSync("git", ["init", "--initial-branch=main", repository], {
      stdio: "pipe",
    });
    for (const [key, value] of [
      ["user.name", "Example"],
      ["user.email", "example@example.invalid"],
      ["core.hooksPath", "/dev/null"],
      ["commit.gpgsign", "false"],
    ])
      git(repository, "config", key ?? "", value ?? "");
    writeFileSync(join(repository, "old.txt"), "one\ntwo\n");
    git(repository, "add", "--all");
    git(repository, "commit", "-m", "Initial");
    git(repository, "checkout", "-b", "feature");
    git(repository, "mv", "old.txt", "new.txt");
    git(repository, "commit", "-m", "Rename");
    git(repository, "checkout", "main");
    git(repository, "commit", "--allow-empty", "-m", "Main");
    git(repository, "merge", "--no-ff", "feature", "-m", "Merge");
    const hash = git(repository, "rev-parse", "HEAD");
    await collect(db, repository);
    assert.equal((await enrich(db, { files: true })).enriched, 4);
    const statistics = db
      .prepare(
        "SELECT files_changed, insertions, deletions FROM commit_enrichment WHERE hash=?",
      )
      .get(hash);
    assert.equal(statistics?.files_changed, 2);
    assert.equal(statistics?.insertions, 2);
    assert.equal(statistics?.deletions, 2);
    assert.deepEqual(
      db
        .prepare("SELECT status FROM commit_files WHERE hash=? ORDER BY path")
        .all(hash)
        .map((file) => file.status),
      ["A", "D"],
    );
  } finally {
    db.close();
    rmSync(root, { recursive: true, force: true });
  }
});

test("partial-clone enrichment never fetches missing blobs or changes the clone", async () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-partial-"));
  const origin = join(root, "origin");
  const partial = join(root, "partial");
  const db = openDatabase(join(root, "db.sqlite"), true);
  try {
    execFileSync("git", ["init", "--initial-branch=main", origin], {
      stdio: "pipe",
    });
    for (const [key, value] of [
      ["user.name", "Example"],
      ["user.email", "example@example.invalid"],
      ["core.hooksPath", "/dev/null"],
      ["commit.gpgsign", "false"],
      ["uploadpack.allowFilter", "true"],
    ])
      git(origin, "config", key ?? "", value ?? "");
    writeFileSync(join(origin, "example.txt"), "one\ntwo\n");
    git(origin, "add", "--all");
    git(origin, "commit", "-m", "Initial");
    const blob = git(origin, "rev-parse", "HEAD:example.txt");
    execFileSync(
      "git",
      [
        "clone",
        "--filter=blob:none",
        "--no-checkout",
        `file://${origin}`,
        partial,
      ],
      { stdio: "pipe" },
    );
    assert.throws(() =>
      git(partial, "--no-lazy-fetch", "cat-file", "-e", blob),
    );
    assert.equal((await collect(db, partial)).added, 1);
    assert.equal((await enrich(db, { files: true })).failures, 1);
    assert.throws(() =>
      git(partial, "--no-lazy-fetch", "cat-file", "-e", blob),
    );
    assert.equal(search(db, { query: "Initial" }).length, 1);
    verifyDatabase(db);
  } finally {
    db.close();
    rmSync(root, { recursive: true, force: true });
  }
});
