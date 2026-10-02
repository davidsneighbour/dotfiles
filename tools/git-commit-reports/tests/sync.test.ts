import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  mkdir,
  readdir,
  readFile,
  rm,
  stat,
  writeFile,
} from "node:fs/promises";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import {
  CONFIG,
  OBSERVATIONS,
  parseConfig,
  type SyncRepository,
} from "../src/config.ts";
import { readCommit } from "../src/git.ts";
import { importCommits } from "../src/importer.ts";
import { commitItemPath } from "../src/model.ts";
import { stableScan } from "../src/scan.ts";
import { syncVault } from "../src/sync.ts";
import {
  PENDING,
  publishTransaction,
  recoverTransaction,
} from "../src/transaction.ts";
import { ARCHIVE, notes, parseNote, STATE, withLock } from "../src/vault.ts";
import { fixture, git } from "./fixtures.ts";

const id = "local-11111111-1111-4111-8111-111111111111";
const otherId = "local-22222222-2222-4222-8222-222222222222";
function entry(repo: string, identity = id): SyncRepository {
  return {
    id: identity,
    paths: [repo],
    canonical_remote: null,
    fetch: "never",
    refs: ["refs/heads/", "refs/remotes/origin/"],
  };
}
async function configure(vault: string, repositories: SyncRepository[]) {
  await mkdir(join(vault, ".obsidian/git-commit-reports"), { recursive: true });
  await writeFile(
    join(vault, CONFIG),
    JSON.stringify({ schema_version: 1, repositories }),
  );
}
async function item(vault: string, hash: string) {
  const found = [...(await notes(vault, `${ARCHIVE}/items`)).values()].find(
    (note) => note.properties["hash"] === hash,
  );
  assert.ok(found);
  return found;
}
async function status(vault: string, hash: string) {
  return (await item(vault, hash)).properties["status"];
}
async function observation(vault: string): Promise<Record<string, unknown>> {
  return JSON.parse(
    await readFile(join(vault, OBSERVATIONS), "utf8"),
  ) as Record<string, unknown>;
}

test("complete scans import missed and backdated history, unchanged notes keep their timestamps", async (t) => {
  const f = await fixture(t);
  await configure(f.vault, [entry(f.repo)]);
  git(f.repo, "commit", "--allow-empty", "-m", "missed one");
  git(f.repo, "commit", "--allow-empty", "-m", "missed two");
  const first = await syncVault({ vault: f.vault });
  assert.equal(first.failed, 0);
  assert.equal(first.repositories[0]?.selected, 3);
  assert.equal(await status(f.vault, f.hash), "reachable");
  const path = join(
    f.vault,
    commitItemPath(readCommit(f.repo, f.hash, "sha1")),
  );
  const before = await stat(path);
  const content = await readFile(path, "utf8");
  const second = await syncVault({ vault: f.vault });
  assert.equal(second.repositories[0]?.changed, 0);
  assert.equal((await stat(path)).mtimeMs, before.mtimeMs);
  assert.equal(await readFile(path, "utf8"), content);
});

test("amend, reappearance, tag retention, branch deletion, and excluded refs", async (t) => {
  const f = await fixture(t);
  await configure(f.vault, [entry(f.repo)]);
  await syncVault({ vault: f.vault });
  git(f.repo, "commit", "--amend", "--allow-empty", "-m", "amended root");
  const amended = git(f.repo, "rev-parse", "HEAD");
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, f.hash), "unreachable");
  assert.equal(await status(f.vault, amended), "reachable");
  git(f.repo, "tag", "-a", "retain", f.hash, "-m", "retain old root");
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, f.hash), "reachable");
  git(f.repo, "tag", "-d", "retain");
  git(f.repo, "update-ref", "refs/stash", f.hash);
  git(f.repo, "update-ref", "refs/replace/example", f.hash);
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, f.hash), "unreachable");
  git(f.repo, "branch", "retained", f.hash);
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, f.hash), "reachable");
  git(f.repo, "branch", "-D", "retained");
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, f.hash), "unreachable");
  assert.equal((await notes(f.vault, `${ARCHIVE}/items`)).size, 2);
});

test("rebase and squash preserve old objects; revert remains a reachable descendant", async (t) => {
  const f = await fixture(t);
  await writeFile(join(f.repo, "file"), "first\n");
  git(f.repo, "add", "file");
  git(f.repo, "commit", "-m", "add file");
  const added = git(f.repo, "rev-parse", "HEAD");
  await configure(f.vault, [entry(f.repo)]);
  await syncVault({ vault: f.vault });
  git(f.repo, "revert", "--no-edit", added);
  const reverted = git(f.repo, "rev-parse", "HEAD");
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, added), "reachable");
  assert.equal(await status(f.vault, reverted), "reachable");
  git(f.repo, "checkout", "-b", "other-base", f.hash);
  git(f.repo, "commit", "--allow-empty", "-m", "new base");
  git(f.repo, "checkout", "main");
  git(f.repo, "rebase", "--empty=keep", "--onto", "other-base", f.hash);
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, added), "unreachable");
  assert.equal(await status(f.vault, reverted), "unreachable");
  const rebased = git(f.repo, "rev-parse", "HEAD");
  git(f.repo, "reset", "--soft", "other-base");
  git(f.repo, "commit", "--allow-empty", "-m", "squashed replacement");
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, rebased), "unreachable");
  assert.equal(
    (await item(f.vault, added)).properties["superseded_by"],
    undefined,
  );
});

test("failed fetch and missing clone preserve verified memberships; other repositories continue", async (t) => {
  const f = await fixture(t);
  const second = await fixture(t);
  await configure(f.vault, [entry(f.repo), entry(second.repo, otherId)]);
  await syncVault({ vault: f.vault });
  const before = await item(f.vault, f.hash);
  const old = await observation(f.vault);
  git(f.repo, "remote", "add", "origin", join(f.root, "missing-upstream"));
  const configured = entry(f.repo);
  configured.fetch = "origin";
  await configure(f.vault, [configured, entry(second.repo, otherId)]);
  const failed = await syncVault({ vault: f.vault });
  assert.equal(failed.failed, 1);
  assert.equal(failed.repositories[1]?.complete, true);
  assert.equal(
    (await item(f.vault, f.hash)).properties["updated"],
    before.properties["updated"],
  );
  const changed = await observation(f.vault);
  const oldEntry = (
    old["repositories"] as Record<string, Record<string, unknown>>
  )[id];
  const newEntry = (
    changed["repositories"] as Record<string, Record<string, unknown>>
  )[id];
  assert.deepEqual(newEntry?.["last_success"], oldEntry?.["last_success"]);
  assert.equal(newEntry?.["complete"], false);
  await rm(f.repo, { recursive: true });
  assert.equal((await syncVault({ vault: f.vault })).failed, 1);
  assert.equal(await status(f.vault, f.hash), "reachable");
});

test("narrow origin fetch handles force-push and deletion without changing worktree or local tags", async (t) => {
  const f = await fixture(t);
  const upstream = join(f.root, "upstream.git");
  git(f.repo, "clone", "--bare", f.repo, upstream);
  git(f.repo, "remote", "add", "origin", upstream);
  git(f.repo, "push", "origin", "main:remote-only");
  const configured = entry(f.repo);
  configured.fetch = "origin";
  await configure(f.vault, [configured]);
  await syncVault({ vault: f.vault });
  git(f.repo, "checkout", "-b", "temporary");
  git(f.repo, "commit", "--allow-empty", "-m", "remote-only commit");
  const remoteOnly = git(f.repo, "rev-parse", "HEAD");
  git(f.repo, "push", "origin", "HEAD:remote-only");
  git(f.repo, "checkout", "main");
  git(f.repo, "branch", "-D", "temporary");
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, remoteOnly), "reachable");
  git(f.repo, "tag", "keep", remoteOnly);
  git(f.repo, "push", "--force", "origin", "main:remote-only");
  const head = git(f.repo, "rev-parse", "HEAD");
  const worktree = git(f.repo, "status", "--porcelain");
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, remoteOnly), "reachable");
  assert.equal(git(f.repo, "rev-parse", "HEAD"), head);
  assert.equal(git(f.repo, "status", "--porcelain"), worktree);
  git(f.repo, "tag", "-d", "keep");
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, remoteOnly), "unreachable");
  git(f.repo, "push", "origin", ":remote-only");
  await syncVault({ vault: f.vault });
  assert.equal(
    spawnSync(
      "git",
      ["-C", f.repo, "show-ref", "--verify", "refs/remotes/origin/remote-only"],
      { stdio: "pipe" },
    ).status,
    128,
  );
});

test("shallow and missing object scans fail without declaring old commits unreachable", async (t) => {
  const f = await fixture(t);
  await configure(f.vault, [entry(f.repo)]);
  await syncVault({ vault: f.vault });
  git(f.repo, "commit", "--allow-empty", "-m", "child");
  const child = git(f.repo, "rev-parse", "HEAD");
  await writeFile(join(f.repo, ".git/shallow"), `${child}\n`);
  assert.equal((await syncVault({ vault: f.vault })).failed, 1);
  assert.equal(await status(f.vault, f.hash), "reachable");
  await rm(join(f.repo, ".git/shallow"));
  await rm(join(f.repo, ".git/objects", child.slice(0, 2), child.slice(2)));
  assert.equal((await syncVault({ vault: f.vault })).failed, 1);
  assert.equal(await status(f.vault, f.hash), "reachable");
});

test("concurrent ref movement retries once, then reports an incomplete scan", async (t) => {
  const f = await fixture(t);
  const config = entry(f.repo);
  let calls = 0;
  const stable = await stableScan(f.repo, config, async (objects) => {
    calls++;
    if (calls === 1) git(f.repo, "commit", "--allow-empty", "-m", "moved once");
    return objects.length;
  });
  assert.equal(calls, 2);
  assert.equal(stable.prepared, 2);
  await assert.rejects(
    stableScan(f.repo, config, async () => {
      git(
        f.repo,
        "commit",
        "--allow-empty",
        "-m",
        `movement-${git(f.repo, "rev-parse", "HEAD")}`,
      );
      return 0;
    }),
    /both scan attempts/,
  );
});

test("dry sync skips fetch and writes, and configuration rejects unsafe identity and ref policies", async (t) => {
  const f = await fixture(t);
  const config = entry(f.repo);
  config.fetch = "origin";
  await configure(f.vault, [config]);
  const before = await readdir(join(f.vault, ".obsidian/git-commit-reports"));
  const dry = await syncVault({ vault: f.vault, dryRun: true });
  assert.equal(dry.failed, 0);
  assert.deepEqual(
    await readdir(join(f.vault, ".obsidian/git-commit-reports")),
    before,
  );
  assert.deepEqual(await readdir(f.vault), [".obsidian"]);
  const unsafeRemote = new URL("https://github.com/test/repo");
  unsafeRemote.username = "test-user";
  unsafeRemote.password = "######";
  for (const repositories of [
    [
      {
        ...config,
        canonical_remote: unsafeRemote.href,
      },
    ],
    [{ ...config, refs: ["refs/stash"] }],
    [config, config],
  ])
    assert.throws(() =>
      parseConfig(JSON.stringify({ schema_version: 1, repositories })),
    );
  const cli = spawnSync(
    "bash",
    [
      fileURLToPath(new URL("../sync.sh", import.meta.url)),
      "--vault",
      f.vault,
      "--dry-run",
      "--quiet",
      "--verbose",
    ],
    { cwd: process.cwd(), encoding: "utf8" },
  );
  assert.equal(cli.status, 0);
  assert.equal(cli.stdout, "");
});

test("interrupted publication rolls back, import refuses its journal, and external edits are preserved", async (t) => {
  const f = await fixture(t);
  await configure(f.vault, [entry(f.repo)]);
  await syncVault({ vault: f.vault });
  const path = commitItemPath(readCommit(f.repo, f.hash, "sha1"));
  const before = await readFile(join(f.vault, path), "utf8");
  const after = `${before}interrupted change\n`;
  await writeFile(
    join(f.vault, PENDING),
    JSON.stringify({ schema_version: 1, changes: [{ path, before, after }] }),
  );
  await writeFile(join(f.vault, path), after);
  await assert.rejects(
    importCommits({ ...f, commit: f.hash }),
    /Interrupted sync/,
  );
  const resumed = await syncVault({ vault: f.vault });
  assert.equal(resumed.recovered, true);
  assert.equal(await readFile(join(f.vault, path), "utf8"), before);
  await writeFile(
    join(f.vault, PENDING),
    JSON.stringify({ schema_version: 1, changes: [{ path, before, after }] }),
  );
  await writeFile(join(f.vault, path), `${after}external edit\n`);
  await withLock(f.vault, async () => {
    await assert.rejects(recoverTransaction(f.vault), /external edit/);
  });
  assert.match(await readFile(join(f.vault, path), "utf8"), /external edit/);
});

test("repository rename retains its ID and config removal retains history", async (t) => {
  const f = await fixture(t);
  git(
    f.repo,
    "remote",
    "add",
    "origin",
    "https://github.com/example/before.git",
  );
  const config = entry(f.repo);
  config.canonical_remote = "https://github.com/example/before";
  await configure(f.vault, [config]);
  await syncVault({ vault: f.vault });
  git(
    f.repo,
    "remote",
    "set-url",
    "origin",
    "https://github.com/example/after.git",
  );
  assert.equal((await syncVault({ vault: f.vault })).failed, 1);
  config.canonical_remote = "https://github.com/example/after";
  await configure(f.vault, [config]);
  assert.equal((await syncVault({ vault: f.vault })).failed, 0);
  const repository = parseNote(
    await readFile(join(f.vault, `${ARCHIVE}/repositories/${id}.md`), "utf8"),
  );
  assert.deepEqual(repository.properties["former_slugs"], ["example/before"]);
  await configure(f.vault, []);
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, f.hash), "reachable");
  assert.ok(await readFile(join(f.vault, STATE), "utf8"));
});

test("shared forks retain aggregate reachability until both drop a commit", async (t) => {
  const f = await fixture(t);
  const fork = join(f.root, "fork");
  git(f.repo, "clone", f.repo, fork);
  git(fork, "config", "user.name", "Test Author");
  git(fork, "config", "user.email", "test@example.invalid");
  git(fork, "config", "commit.gpgsign", "false");
  await configure(f.vault, [entry(f.repo), entry(fork, otherId)]);
  await syncVault({ vault: f.vault });
  git(f.repo, "commit", "--amend", "--allow-empty", "-m", "rewritten");
  await syncVault({ vault: f.vault });
  const shared = await item(f.vault, f.hash);
  assert.equal(shared.properties["status"], "reachable");
  assert.deepEqual(shared.properties["unreachable_in"], [id]);
  assert.deepEqual(shared.properties["reachable_in"], [otherId]);
  git(fork, "commit", "--amend", "--allow-empty", "-m", "fork rewritten");
  git(fork, "update-ref", "-d", "refs/remotes/origin/main");
  await syncVault({ vault: f.vault });
  assert.equal(await status(f.vault, f.hash), "unreachable");
});

test("deleted final branch produces a complete empty observation and preserves notes", async (t) => {
  const f = await fixture(t);
  await configure(f.vault, [entry(f.repo)]);
  await syncVault({ vault: f.vault });
  git(f.repo, "update-ref", "-d", "refs/heads/main");
  const result = await syncVault({ vault: f.vault });
  assert.equal(result.failed, 0);
  assert.equal(result.repositories[0]?.selected, 0);
  assert.equal(await status(f.vault, f.hash), "unreachable");
});

test("publication refuses archive edits made after preparation", async (t) => {
  const f = await fixture(t);
  const path = `${ARCHIVE}/test.md`;
  await mkdir(join(f.vault, ARCHIVE), { recursive: true });
  await writeFile(join(f.vault, path), "original");
  await withLock(f.vault, async () => {
    const originals = new Map([[path, "original"]]);
    await writeFile(join(f.vault, path), "external edit");
    await assert.rejects(
      publishTransaction(f.vault, new Map([[path, "replacement"]]), originals),
      /changed during scan/,
    );
  });
  assert.equal(await readFile(join(f.vault, path), "utf8"), "external edit");
});

test("CLI returns non-zero on partial failure and prints safe per-repository results", async (t) => {
  const f = await fixture(t);
  await configure(f.vault, [
    entry(join(f.root, "missing")),
    entry(f.repo, otherId),
  ]);
  const cli = spawnSync(
    process.execPath,
    [
      "--experimental-strip-types",
      fileURLToPath(new URL("../src/sync-cli.ts", import.meta.url)),
      "--vault",
      f.vault,
      "--dry-run",
      "--verbose",
    ],
    {
      encoding: "utf8",
      env: { ...process.env, GIT_COMMIT_REPORTS_LOGGING: "1" },
    },
  );
  assert.equal(cli.status, 1);
  assert.match(cli.stderr, /No configured clone/);
  assert.match(cli.stdout, /failed=1/);
  assert.match(cli.stdout, /selected=1/);
  assert.ok(!cli.stdout.includes("Full message"));
  assert.ok(!cli.stderr.includes("Full message"));
});
