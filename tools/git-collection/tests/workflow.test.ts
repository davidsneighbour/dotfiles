import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { once } from "node:events";
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { collect } from "../src/collector.ts";
import { runDaily } from "../src/daily.ts";
import {
  openDatabase,
  rebuildSearch,
  verifyDatabase,
} from "../src/database.ts";
import {
  type DiscoveryConfig,
  discover,
  loadConfig,
} from "../src/discovery.ts";
import { enrich } from "../src/enrichment.ts";
import { search } from "../src/query.ts";
import { rebuild, snapshotDatabase } from "../src/recovery.ts";
import { scanAll } from "../src/scanner.ts";

function git(repository: string, ...args: string[]): string {
  return execFileSync("git", ["-C", repository, ...args], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

function createRepository(path: string): void {
  execFileSync("git", ["init", "--initial-branch=main", path], {
    stdio: "pipe",
  });
  git(path, "config", "user.name", "Example");
  git(path, "config", "user.email", "example@example.invalid");
  git(path, "config", "core.hooksPath", "/dev/null");
  git(path, "config", "commit.gpgsign", "false");
  git(
    path,
    "commit",
    "--allow-empty",
    "-m",
    "Initial reduced motion",
    "-m",
    "Multiline\nUnicode café",
  );
}

test("incremental checkpoints, rewritten history, disappearing clone, shallow clone, and recovery", async () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-workflow-"));
  const repos = join(root, "repositories");
  const repository = join(repos, "one");
  const database = join(root, "catalogue.sqlite");
  const config: DiscoveryConfig = { roots: [repos], exclude: [], maxDepth: 2 };
  const db = openDatabase(database, true);
  try {
    createRepository(repository);
    git(
      repository,
      "remote",
      "add",
      "origin",
      "https://user:password@example.invalid/repo?token=private",
    );
    const initial = await scanAll(db, database, config);
    assert.equal(initial.commitsAdded, 1);
    assert.equal(initial.failures, 0);
    assert.ok(
      !String(
        db.prepare("SELECT remotes_json FROM repositories").get()?.remotes_json,
      ).includes("password"),
    );
    assert.equal((await collect(db, repository)).mode, "unchanged");
    git(repository, "commit", "--allow-empty", "-m", "Second commit");
    const incremental = await collect(db, repository);
    assert.equal(incremental.mode, "incremental");
    assert.equal(incremental.seen, 1);
    assert.equal(incremental.added, 1);
    const old = git(repository, "rev-parse", "HEAD");
    git(repository, "reset", "--hard", "HEAD~1");
    git(repository, "commit", "--allow-empty", "-m", "Replacement commit");
    assert.equal((await collect(db, repository)).added, 1);
    assert.equal(
      db.prepare("SELECT reachability FROM commits WHERE hash=?").get(old)
        ?.reachability,
      "unreachable",
    );
    const shallow = join(repos, "shallow");
    execFileSync(
      "git",
      ["clone", "--depth=1", `file://${repository}`, shallow],
      { stdio: "pipe" },
    );
    assert.equal((await collect(db, shallow)).seen, 1);
    assert.equal((await collect(db, shallow)).mode, "full");
    assert.equal((await enrich(db, { repository: shallow })).failures, 1);
    execFileSync("git", ["-C", shallow, "fetch", "--unshallow"], {
      stdio: "pipe",
    });
    assert.equal((await collect(db, shallow)).added, 1);
    assert.equal((await enrich(db, { repository: shallow })).enriched, 2);
    const snapshot = join(root, "snapshot.sqlite");
    await snapshotDatabase(db, snapshot);
    assert.equal(statSync(snapshot).mode & 0o777, 0o600);
    await assert.rejects(snapshotDatabase(db, snapshot), /already exists/);
    const snapshotReader = openDatabase(snapshot);
    verifyDatabase(snapshotReader);
    assert.equal(
      snapshotReader.prepare("SELECT count(*) AS n FROM commits").get()?.n,
      5,
    );
    snapshotReader.close();
    // Restore a real snapshot to a replacement working file, then query and verify it.
    const restoredPath = join(root, "restored.sqlite");
    copyFileSync(snapshot, restoredPath);
    const restored = openDatabase(restoredPath);
    verifyDatabase(restored);
    assert.equal(search(restored, { query: '"reduced motion"' }).length, 2);
    restored.close();
    const rebuiltPath = join(root, "rebuilt.sqlite");
    const rebuiltSummary = await rebuild(rebuiltPath, config);
    assert.equal(rebuiltSummary.commitsAdded, 4);
    const rebuilt = openDatabase(rebuiltPath);
    verifyDatabase(rebuilt);
    assert.equal(
      rebuilt.prepare("SELECT count(*) AS n FROM commits").get()?.n,
      4,
    );
    rebuilt.close();
    await assert.rejects(rebuild(database, config), /already exists/);
    await assert.rejects(
      rebuild(join(root, "failed.sqlite"), {
        ...config,
        roots: [join(root, "missing")],
      }),
      /Rebuild failed/,
    );
    assert.throws(() => statSync(join(root, "failed.sqlite")), /ENOENT/);
    rmSync(shallow, { recursive: true });
    const missing = await scanAll(db, database, config);
    assert.equal(missing.failures, 1);
    assert.equal(
      db
        .prepare(
          "SELECT count(*) AS n FROM commits WHERE reachability='unknown'",
        )
        .get()?.n,
      2,
    );
  } finally {
    db.close();
    rmSync(root, { recursive: true, force: true });
  }
});

test("discovery includes nested repos, worktrees, and bare repos, respects depth and exclusions, and skips symlinks", () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-discovery-"));
  try {
    const repository = join(root, "one");
    createRepository(repository);
    createRepository(join(repository, "nested"));
    const worktree = join(root, "worktree");
    git(repository, "worktree", "add", "-b", "worktree", worktree);
    execFileSync(
      "git",
      ["clone", "--bare", repository, join(root, "bare.git")],
      { stdio: "pipe" },
    );
    symlinkSync(repository, join(root, "linked"));
    createRepository(join(root, "node_modules", "ignored"));
    const config: DiscoveryConfig = {
      roots: [root, repository],
      exclude: [join(repository, "nested")],
      maxDepth: 2,
    };
    assert.deepEqual(
      discover(config).repositories,
      [join(root, "bare.git"), repository, worktree].sort(),
    );
    assert.equal(
      discover({ ...config, roots: [root], exclude: [], maxDepth: 0 })
        .repositories.length,
      0,
    );
    assert.equal(
      discover({ ...config, roots: [join(root, "missing")] }).errors.length,
      1,
    );
    const configPath = join(root, "config.json");
    writeFileSync(
      configPath,
      JSON.stringify({ roots: ["one"], exclude: [], maxDepth: 0 }),
    );
    assert.deepEqual(loadConfig(configPath).roots, [repository]);
    writeFileSync(
      configPath,
      JSON.stringify({ roots: ["one"], unknown: true }),
    );
    assert.throws(() => loadConfig(configPath), /Unknown/);
    writeFileSync(configPath, JSON.stringify({ roots: ["one"], maxDepth: -1 }));
    assert.throws(() => loadConfig(configPath), /maxDepth/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("search remains synchronised through insert, metadata edits, repository rename, deletion, and rebuilding", async () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-search-"));
  const db = openDatabase(join(root, "catalogue.sqlite"), true);
  try {
    const repository = join(root, "one");
    createRepository(repository);
    await collect(db, repository);
    assert.equal(
      search(db, {
        query: '"reduced motion"',
        author: "example@example.invalid",
        repository: "one",
      }).length,
      1,
    );
    assert.equal(search(db, { query: "café" }).length, 1);
    assert.equal(
      search(db, { query: "motion", author: "other@example.invalid" }).length,
      0,
    );
    assert.throws(
      () => search(db, { query: "motion", since: "2026-02-31" }),
      /valid/,
    );
    db.prepare("UPDATE commits SET subject=?, committer_date=?").run(
      "New subject",
      "2026-10-02T18:30:00+00:00",
    );
    assert.equal(search(db, { query: "motion" }).length, 0);
    assert.equal(
      search(db, { query: "New", since: "2026-10-03", until: "2026-10-03" })
        .length,
      1,
    );
    assert.equal(
      db.prepare("SELECT activity_date FROM v_commits").get()?.activity_date,
      "2026-10-03",
    );
    assert.equal(
      db.prepare("SELECT commits FROM v_daily_activity").get()?.commits,
      1,
    );
    db.prepare("UPDATE repositories SET name=?").run("Renamed");
    assert.equal(search(db, { query: "Renamed" }).length, 1);
    assert.equal(search(db, { query: "repository:one" }).length, 0);
    rebuildSearch(db);
    assert.equal(search(db, { query: "New" }).length, 1);
    db.exec("DELETE FROM commits");
    assert.equal(search(db, { query: "New" }).length, 0);
    verifyDatabase(db);
  } finally {
    db.close();
    rmSync(root, { recursive: true, force: true });
  }
});

test("SIGKILL during a real write transaction leaves no partial commits and can be rerun", async () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-kill-"));
  const repository = join(root, "repo");
  const path = join(root, "db.sqlite");
  createRepository(repository);
  const worker = spawn(
    process.execPath,
    [
      fileURLToPath(new URL("./interrupted-worker.ts", import.meta.url)),
      path,
      repository,
    ],
    {
      stdio: ["ignore", "pipe", "pipe"],
    },
  );
  let stderr = "";
  worker.stderr.on("data", (chunk: Buffer) => {
    stderr += chunk.toString();
  });
  const closed = once(worker, "close");
  try {
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(
        () => reject(new Error(`Worker did not reach transaction: ${stderr}`)),
        10000,
      );
      worker.stdout.once("data", () => {
        clearTimeout(timer);
        resolve();
      });
      worker.once("close", () => {
        clearTimeout(timer);
        reject(new Error(`Worker exited early: ${stderr}`));
      });
    });
    worker.kill("SIGKILL");
    await closed;
    const db = openDatabase(path, true);
    try {
      verifyDatabase(db);
      assert.equal(db.prepare("SELECT count(*) AS n FROM commits").get()?.n, 0);
      assert.equal(
        db
          .prepare(
            "SELECT count(*) AS n FROM collection_runs WHERE state='running'",
          )
          .get()?.n,
        1,
      );
      assert.equal((await collect(db, repository)).added, 1);
      verifyDatabase(db);
    } finally {
      db.close();
    }
  } finally {
    worker.kill("SIGKILL");
    await closed;
    rmSync(root, { recursive: true, force: true });
  }
});

test("CLI validates flags and emits usable status, search, discovery, and snapshots", () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-cli-"));
  const cli = fileURLToPath(new URL("../src/cli.ts", import.meta.url));
  const database = join(root, "catalogue.sqlite");
  const run = (...args: string[]): string =>
    execFileSync(process.execPath, [cli, ...args, "--database", database], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  try {
    const repository = join(root, "repo");
    createRepository(repository);
    assert.match(run("init"), /ready/);
    assert.equal(JSON.parse(run("scan", "--repository", repository)).added, 1);
    assert.equal(JSON.parse(run("status")).commits, 1);
    assert.equal(JSON.parse(run("search", "--query", "motion")).length, 1);
    assert.match(run("verify"), /passed/);
    assert.equal(
      JSON.parse(run("discover", "--root", repository, "--max-depth", "0"))
        .repositories.length,
      1,
    );
    assert.throws(() => run("status", "--all"), /Command failed/);
    assert.throws(() => run("scan"), /Command failed/);
    const snapshot = join(root, "snapshot.sqlite");
    assert.match(run("backup", "--destination", snapshot), /Verified snapshot/);
    assert.ok(readFileSync(snapshot).length > 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("daily runner logs consecutive scans, reports failures, and rejects unavailable log directories", async () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-daily-"));
  try {
    const repository = join(root, "repo");
    createRepository(repository);
    const config = join(root, "config.json");
    writeFileSync(config, JSON.stringify({ roots: [repository], maxDepth: 0 }));
    const database = join(root, "catalogue.sqlite");
    const first = await runDaily({ config, database }, root);
    assert.equal(first.code, 0);
    assert.equal(
      first.logPath.startsWith(join(root, ".logs/git-collection/")),
      true,
    );
    assert.match(first.logPath.split("/").at(-1) ?? "", /^\d{8}-\d{6}\.log$/);
    assert.match(readFileSync(first.logPath, "utf8"), /"commitsAdded": 1/);
    assert.equal(statSync(first.logPath).mode & 0o777, 0o600);
    const second = await runDaily({ config, database }, root);
    assert.equal(second.code, 0);
    assert.match(
      readFileSync(second.logPath, "utf8"),
      /"repositoriesChanged": 0/,
    );
    const third = await runDaily({ config, database }, root);
    assert.equal(third.code, 0);
    const failed = await runDaily(
      { config: join(root, "missing.json"), database },
      root,
    );
    assert.equal(failed.code, 1);
    assert.match(readFileSync(failed.logPath, "utf8"), /missing.json/);
    const blocked = join(root, "blocked");
    mkdirSync(join(blocked, ".logs"), { recursive: true });
    writeFileSync(join(blocked, ".logs", "git-collection"), "Not a directory");
    await assert.rejects(runDaily({ config, database }, blocked), /EEXIST/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("pruned checkpoint tips force full extraction and failed scans preserve uncertain history", async () => {
  const root = mkdtempSync(join(tmpdir(), "git-collection-pruned-"));
  const repository = join(root, "repo");
  const db = openDatabase(join(root, "catalogue.sqlite"), true);
  try {
    createRepository(repository);
    git(repository, "commit", "--allow-empty", "-m", "Old tip");
    await collect(db, repository);
    const old = git(repository, "rev-parse", "HEAD");
    git(repository, "reset", "--hard", "HEAD~1");
    git(repository, "commit", "--allow-empty", "-m", "New tip");
    git(repository, "reflog", "expire", "--expire=now", "--all");
    git(repository, "gc", "--prune=now");
    assert.equal((await collect(db, repository)).mode, "full");
    assert.equal(
      db.prepare("SELECT reachability FROM commits WHERE hash=?").get(old)
        ?.reachability,
      "unreachable",
    );
    db.exec(
      `CREATE TRIGGER reject_import BEFORE INSERT ON commits BEGIN SELECT RAISE(ABORT, 'Forced failure'); END;`,
    );
    await assert.rejects(collect(db, repository, true), /Forced failure/);
    assert.equal(
      db
        .prepare(
          "SELECT count(*) AS n FROM commits WHERE reachability='unknown'",
        )
        .get()?.n,
      3,
    );
    assert.equal(
      db.prepare("SELECT scan_state FROM repositories").get()?.scan_state,
      "failed",
    );
    db.exec("DROP TRIGGER reject_import");
    assert.equal((await collect(db, repository)).mode, "full");
    assert.equal(
      db.prepare("SELECT reachability FROM commits WHERE hash=?").get(old)
        ?.reachability,
      "unreachable",
    );
    verifyDatabase(db);
  } finally {
    db.close();
    rmSync(root, { recursive: true, force: true });
  }
});
