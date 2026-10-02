import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  mkdir,
  readdir,
  readFile,
  rm,
  stat,
  symlink,
  writeFile,
} from "node:fs/promises";
import { join } from "node:path";
import { test } from "node:test";
import {
  canonicalRemote,
  readCommit,
  repositoryInfo,
  resolveCommit,
  selectCommits,
} from "../src/git.ts";
import { importCommits } from "../src/importer.ts";
import { commitItemPath } from "../src/model.ts";
import {
  ARCHIVE,
  atomicWrite,
  notes,
  parseNote,
  STATE,
  serialise,
  strings,
  withLock,
} from "../src/vault.ts";
import { fixture, git } from "./fixtures.ts";

test("raw messages, root commits, SHA-256, and unchanged imports", async (t) => {
  for (const format of ["sha1", "sha256"] as const) {
    const f = await fixture(t, format);
    const object = readCommit(f.repo, f.hash, format);
    assert.equal(object.parents.length, 0);
    assert.match(object.message, /Full message\nwith delimiter/);
    const first = await importCommits({ ...f, commit: f.hash });
    assert.equal(first.changed, 2);
    const path = join(f.vault, commitItemPath(object));
    const before = await stat(path);
    const again = await importCommits({ ...f, commit: f.hash });
    assert.equal(again.changed, 0);
    assert.equal((await stat(path)).mtimeMs, before.mtimeMs);
    const note = parseNote(await readFile(path, "utf8"));
    assert.equal(note.body, object.message);
    assert.equal(note.properties["status"], "unknown");
  }
});

test("dry-run creates no registrations or directories and rejects invalid selection", async (t) => {
  const f = await fixture(t);
  await importCommits({ ...f, recent: 1, dryRun: true });
  assert.deepEqual(await readdir(f.vault), []);
  for (const selection of [
    { recent: 0 },
    { recent: 1, commit: f.hash },
    { from: "2026-10-01" },
    { from: "2026-02-30", to: "2026-10-01" },
  ])
    await assert.rejects(importCommits({ ...f, ...selection }));
  assert.deepEqual(await readdir(f.vault), []);
});

test("forks share one object, clones and worktrees reuse identity, and credentials are redacted", async (t) => {
  const f = await fixture(t);
  const origin = new URL("https://github.com/Example/Original.git");
  origin.username = "test-user";
  origin.password = "######";
  origin.searchParams.set("token", "######");
  git(f.repo, "remote", "add", "origin", origin.href);
  const first = await importCommits({ ...f, commit: f.hash });
  const clone = join(f.root, "clone");
  git(f.repo, "clone", f.repo, clone);
  git(
    clone,
    "remote",
    "set-url",
    "origin",
    "git@github.com:example/original.git",
  );
  assert.equal(
    (await importCommits({ repo: clone, vault: f.vault, commit: f.hash }))
      .repositoryId,
    first.repositoryId,
  );
  const worktree = join(f.root, "worktree");
  git(f.repo, "worktree", "add", "--detach", worktree);
  assert.equal(
    (await importCommits({ repo: worktree, vault: f.vault, commit: f.hash }))
      .repositoryId,
    first.repositoryId,
  );
  git(clone, "remote", "set-url", "origin", "git@github.com:example/fork.git");
  await assert.rejects(
    importCommits({ repo: clone, vault: f.vault, commit: f.hash }),
    /Origin changed/,
  );
  const fork = join(f.root, "fork");
  git(f.repo, "clone", f.repo, fork);
  git(fork, "remote", "set-url", "origin", "git@github.com:example/fork.git");
  const second = await importCommits({
    repo: fork,
    vault: f.vault,
    commit: f.hash,
  });
  assert.notEqual(first.repositoryId, second.repositoryId);
  const items = await notes(f.vault, `${ARCHIVE}/items`);
  assert.equal(items.size, 1);
  assert.equal(
    strings(
      [...items.values()][0]?.properties["repository_ids"],
      "repository_ids",
    ).length,
    2,
  );
  for (const note of (await notes(f.vault, `${ARCHIVE}/repositories`)).values())
    assert.ok(!serialise(note.properties, note.body).includes("secret"));
  assert.equal(
    canonicalRemote("ssh://git@github.com/example/original.git"),
    "https://github.com/example/original",
  );
});

test("labels, tags, unknown properties, and comments survive; body and metadata conflicts preserve files", async (t) => {
  const f = await fixture(t);
  await importCommits({ ...f, commit: f.hash });
  const path = join(
    f.vault,
    commitItemPath(readCommit(f.repo, f.hash, "sha1")),
  );
  const note = parseNote(await readFile(path, "utf8"));
  note.properties["labels"] = ["reviewed"];
  note.properties["tags"] = ["personal", "git-commit"];
  note.properties["custom"] = { key: "value" };
  await writeFile(
    path,
    serialise(note.properties, note.body, note).replace(
      "labels:",
      "# Keep this comment\nlabels:",
    ),
  );
  await importCommits({ ...f, commit: f.hash });
  const source = await readFile(path, "utf8");
  assert.match(source, /Keep this comment/);
  const result = parseNote(source);
  assert.deepEqual(result.properties["labels"], ["reviewed"]);
  assert.deepEqual(result.properties["custom"], { key: "value" });
  const edited = `${source}Manual body edit\n`;
  await writeFile(path, edited);
  await assert.rejects(
    importCommits({ ...f, commit: f.hash }),
    /body conflict/,
  );
  assert.equal(await readFile(path, "utf8"), edited);
  result.properties["author_name"] = "Other";
  await writeFile(path, serialise(result.properties, result.body));
  await assert.rejects(
    importCommits({ ...f, commit: f.hash }),
    /Immutable metadata conflict/,
  );
});

test("merges, full traversal date filtering, non-commit rejection, and replace objects", async (t) => {
  const f = await fixture(t);
  git(f.repo, "checkout", "-b", "side");
  git(f.repo, "commit", "--allow-empty", "-m", "side");
  const side = git(f.repo, "rev-parse", "HEAD");
  git(f.repo, "checkout", "main");
  git(f.repo, "commit", "--allow-empty", "-m", "main");
  git(f.repo, "merge", "--no-ff", "side", "-m", "merge");
  const merge = readCommit(f.repo, git(f.repo, "rev-parse", "HEAD"), "sha1");
  assert.equal(merge.parents.length, 2);
  assert.equal(selectCommits(f.repo, "sha1", { recent: 4 }).length, 4);
  assert.equal(
    selectCommits(f.repo, "sha1", { from: "2026-10-01", to: "2026-10-01" })
      .length,
    4,
  );
  assert.equal(
    selectCommits(f.repo, "sha1", { from: "2026-10-02", to: "2026-10-02" })
      .length,
    0,
  );
  assert.throws(
    () => resolveCommit(f.repo, "HEAD^{tree}", "sha1"),
    /commit object/,
  );
  git(f.repo, "tag", "-a", "tag", "-m", "tag");
  assert.throws(() => resolveCommit(f.repo, "tag", "sha1"), /commit object/);
  git(f.repo, "replace", f.hash, side);
  assert.equal(readCommit(f.repo, f.hash, "sha1").parents.length, 0);
});

test("malformed notes, concurrent writers, symlinks, and interrupted-write leftovers", async (t) => {
  const f = await fixture(t);
  await withLock(f.vault, async () => {
    await assert.rejects(importCommits({ ...f, commit: f.hash }), /locked/);
  });
  await mkdir(join(f.vault, `${ARCHIVE}/items`), { recursive: true });
  await writeFile(
    join(f.vault, `${ARCHIVE}/items/bad.md`),
    "---\nhash: a\nhash: b\n---\n",
  );
  await assert.rejects(importCommits({ ...f, commit: f.hash }), /Cannot parse/);
  await rm(join(f.vault, `${ARCHIVE}/items/bad.md`));
  await writeFile(
    join(f.vault, `${ARCHIVE}/items/old.tmp`),
    "interrupted write",
  );
  await importCommits({ ...f, commit: f.hash });
  assert.equal((await importCommits({ ...f, commit: f.hash })).changed, 0);
  const outside = join(f.root, "outside");
  await mkdir(outside);
  await symlink(outside, join(f.vault, `${ARCHIVE}/items/link`));
  await assert.rejects(importCommits({ ...f, commit: f.hash }), /Symlink/);
  assert.deepEqual(await readdir(outside), []);
  await assert.rejects(
    atomicWrite(f.vault, "../outside/test", "no"),
    /escapes/,
  );
  assert.ok(await readFile(join(f.vault, STATE), "utf8"));
  assert.ok(repositoryInfo(f.repo).common);
});

test("ambiguous names are rejected and explicit IDs recover local clone registration", async (t) => {
  const f = await fixture(t);
  git(f.repo, "branch", "collision");
  git(f.repo, "tag", "collision");
  assert.throws(() => resolveCommit(f.repo, "collision", "sha1"), /Ambiguous/);
  const first = await importCommits({ ...f, commit: f.hash });
  await rm(join(f.vault, STATE));
  const recovered = await importCommits({
    ...f,
    commit: f.hash,
    repositoryId: first.repositoryId,
  });
  assert.equal(recovered.changed, 0);
  assert.equal(recovered.repositoryId, first.repositoryId);
  await assert.rejects(
    importCommits({ ...f, commit: f.hash, repositoryId: "github-123" }),
    /conflicts/,
  );
});

test("date filtering finds backdated ancestors beyond newer children", async (t) => {
  const f = await fixture(t);
  execFileSync(
    "git",
    ["-C", f.repo, "commit", "--allow-empty", "-m", "newer child"],
    {
      env: {
        ...process.env,
        GIT_AUTHOR_DATE: "2026-10-04T12:00:00+07:00",
        GIT_COMMITTER_DATE: "2026-10-04T12:00:00+07:00",
      },
      stdio: "pipe",
    },
  );
  const selected = selectCommits(f.repo, "sha1", {
    from: "2026-10-01",
    to: "2026-10-01",
  });
  assert.deepEqual(
    selected.map((entry) => entry.hash),
    [f.hash],
  );
});

test("registration cache survives interruption before repository-note publication", async (t) => {
  const f = await fixture(t);
  const first = await importCommits({ ...f, commit: f.hash });
  await rm(join(f.vault, `${ARCHIVE}/repositories/${first.repositoryId}.md`));
  const resumed = await importCommits({ ...f, commit: f.hash });
  assert.equal(resumed.repositoryId, first.repositoryId);
  assert.equal(resumed.changed, 1);
  assert.equal((await importCommits({ ...f, commit: f.hash })).changed, 0);
});
