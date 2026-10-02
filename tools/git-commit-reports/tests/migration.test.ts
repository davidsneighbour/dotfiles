import assert from "node:assert/strict";
import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { test } from "node:test";
import { parseDocument } from "yaml";
import { CONFIG } from "../src/config.ts";
import { readCommit } from "../src/git.ts";
import { importCommits } from "../src/importer.ts";
import { inventoryLegacy } from "../src/legacy.ts";
import { migrateLegacy } from "../src/migrate.ts";
import { commitItemPath } from "../src/model.ts";
import { syncVault } from "../src/sync.ts";
import {
  PENDING,
  publishTransaction,
  recoverTransaction,
} from "../src/transaction.ts";
import { ARCHIVE, notes, parseNote, serialise } from "../src/vault.ts";
import { installViews } from "../src/views.ts";
import { fixture, git } from "./fixtures.ts";

async function report(
  vault: string,
  hash: string,
  date = "2025-01-01",
  repository = "example/repo",
) {
  const path = `${ARCHIVE}/${date.replaceAll("-", "/")}-Wednesday.md`;
  await mkdir(join(vault, path, ".."), { recursive: true });
  const source = `---\ntitle: ${date}\ntags: [gitreport, daily]\n---\n\n## Person-looking heading\n\n* **06:01:** [\`${hash.slice(0, 12)}\`](https://github.com/${repository}/commit/${hash}) A recovered subject\n`;
  await writeFile(join(vault, path), source);
  return { path, source };
}
async function configure(vault: string, repo: string, id: string) {
  await mkdir(join(vault, ".obsidian/git-commit-reports"), { recursive: true });
  await writeFile(
    join(vault, CONFIG),
    JSON.stringify({
      schema_version: 1,
      repositories: [
        {
          id,
          paths: [repo],
          canonical_remote: "https://github.com/example/repo",
          fetch: "never",
        },
      ],
    }),
  );
}

test("inventory deduplicates objects, preserves report provenance, and never guesses identities", async (t) => {
  const f = await fixture(t);
  const original = await report(f.vault, f.hash);
  await report(f.vault, f.hash, "2025-01-02");
  const dry = await migrateLegacy({ vault: f.vault, dryRun: true });
  assert.equal(dry.inventory.hashes, 1);
  assert.equal(dry.inventory.duplicates, 1);
  assert.deepEqual(await readdir(f.vault), ["23 Eventlog"]);
  const applied = await migrateLegacy({ vault: f.vault });
  assert.equal(applied.reportOnly, 1);
  const all = await notes(f.vault, `${ARCHIVE}/items`);
  const item = [...all.values()][0];
  assert.ok(item);
  assert.equal(item.properties["metadata_complete"], false);
  assert.deepEqual(item.properties["disabled rules"], ["all"]);
  assert.equal(item.properties["author_name"], undefined);
  assert.equal(item.properties["committed_at"], undefined);
  assert.equal(item.properties["status"], "unknown");
  assert.equal(item.properties["date"], "2025-01-01");
  assert.equal((item.properties["legacy_reports"] as string[]).length, 2);
  assert.equal(
    await readFile(join(f.vault, original.path), "utf8"),
    original.source,
  );
  assert.equal((await migrateLegacy({ vault: f.vault })).changed, 0);
});

test("publication and recovery refuse legacy report destinations", async (t) => {
  const f = await fixture(t);
  const original = await report(f.vault, f.hash);
  await assert.rejects(
    publishTransaction(f.vault, new Map([[original.path, "replacement"]])),
    /Invalid pending sync journal entry/,
  );
  await mkdir(join(f.vault, ".obsidian/git-commit-reports"), {
    recursive: true,
  });
  await writeFile(
    join(f.vault, PENDING),
    JSON.stringify({
      schema_version: 1,
      changes: [
        { path: original.path, before: "older", after: original.source },
      ],
    }),
  );
  await assert.rejects(
    recoverTransaction(f.vault),
    /Invalid pending sync journal entry/,
  );
  assert.equal(
    await readFile(join(f.vault, original.path), "utf8"),
    original.source,
  );
});

test("enrichment relocates under lock with a recoverable redirect and retains user fields", async (t) => {
  const f = await fixture(t);
  await report(f.vault, f.hash);
  await migrateLegacy({ vault: f.vault });
  const oldPath = `${ARCHIVE}/items/2025/01/01/${f.hash}.md`;
  const old = parseNote(await readFile(join(f.vault, oldPath), "utf8"));
  old.properties["labels"] = ["reviewed"];
  old.properties["custom"] = "keep";
  old.properties["superseded_by"] = ["[[Elsewhere]]"];
  await writeFile(
    join(f.vault, oldPath),
    serialise(old.properties, old.body, old),
  );
  git(f.repo, "remote", "add", "origin", "https://github.com/example/repo.git");
  const id = (old.properties["repository_ids"] as string[])[0];
  assert.ok(id);
  await configure(f.vault, f.repo, id);
  const dry = await migrateLegacy({ vault: f.vault, dryRun: true });
  assert.equal(dry.recovered, 1);
  assert.equal(
    parseNote(await readFile(join(f.vault, oldPath), "utf8")).properties[
      "metadata_complete"
    ],
    false,
  );
  const applied = await migrateLegacy({ vault: f.vault });
  assert.equal(applied.recovered, 1);
  assert.equal(applied.changed, dry.changed);
  const canonical = commitItemPath(readCommit(f.repo, f.hash, "sha1"));
  const item = parseNote(await readFile(join(f.vault, canonical), "utf8"));
  assert.equal(item.properties["metadata_complete"], true);
  assert.deepEqual(item.properties["labels"], ["reviewed"]);
  assert.equal(item.properties["custom"], "keep");
  assert.deepEqual(item.properties["superseded_by"], ["[[Elsewhere]]"]);
  assert.equal(item.body, readCommit(f.repo, f.hash, "sha1").message);
  assert.equal(
    parseNote(await readFile(join(f.vault, oldPath), "utf8")).properties[
      "type"
    ],
    "git-commit-redirect",
  );
  assert.equal((await migrateLegacy({ vault: f.vault })).changed, 0);
  assert.equal((await importCommits({ ...f, commit: f.hash })).changed, 0);
  assert.equal((await syncVault({ vault: f.vault })).failed, 0);
});

test("Git-backed vaults refuse unignored records and preserve duplicate or edited bodies", async (t) => {
  const f = await fixture(t);
  await report(f.vault, f.hash);
  git(f.vault, "init", "-b", "main");
  await assert.rejects(
    migrateLegacy({ vault: f.vault }),
    /untracked and ignored/,
  );
  await writeFile(
    join(f.vault, ".git/info/exclude"),
    `${ARCHIVE}/items/\n${ARCHIVE}/repositories/\n.obsidian/git-commit-reports/\n`,
  );
  await migrateLegacy({ vault: f.vault });
  const path = `${ARCHIVE}/items/2025/01/01/${f.hash}.md`;
  const source = await readFile(join(f.vault, path), "utf8");
  await writeFile(join(f.vault, path), `${source}manual edit\n`);
  await assert.rejects(migrateLegacy({ vault: f.vault }), /digest/);
  assert.match(await readFile(join(f.vault, path), "utf8"), /manual edit/);
  await writeFile(join(f.vault, path), source);
  await writeFile(join(f.vault, `${ARCHIVE}/items/duplicate.md`), source);
  await assert.rejects(
    migrateLegacy({ vault: f.vault }),
    /duplicate canonical/,
  );
});

test("Bases supply all required views and freshness projections without rewriting originals", async (t) => {
  const f = await fixture(t);
  await report(f.vault, f.hash);
  await migrateLegacy({ vault: f.vault });
  await installViews(f.vault);
  assert.equal(await installViews(f.vault), 0);
  const base = parseDocument(
    await readFile(join(f.vault, `${ARCHIVE}/Commits.base`), "utf8"),
  ).toJS() as { views: { name: string }[] };
  assert.deepEqual(
    base.views.map((view) => view.name),
    ["All", "Current", "Unreachable", "Uncertain", "Merges"],
  );
  const repositories = parseDocument(
    await readFile(join(f.vault, `${ARCHIVE}/Repositories.base`), "utf8"),
  ).toJS() as { formulas: Record<string, string> };
  assert.ok(
    repositories.formulas["last_success"]?.includes("properties.last_success"),
  );
  await writeFile(join(f.vault, `${ARCHIVE}/Commits.base`), "views: []\n");
  await assert.rejects(installViews(f.vault), /preserve custom/);
  assert.equal((await inventoryLegacy(f.vault)).reports, 1);
});
