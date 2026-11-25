import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import {
  mkdtemp,
  readFile,
  rm,
  stat,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { ZipFile } from "yazl";
import {
  candidateConfig,
  configSchema,
  readConfig,
  resolveConfig,
} from "../src/config.ts";
import type { State } from "../src/model.ts";
import { duplicateGroups, hash, identify } from "../src/model.ts";
import {
  adopt,
  adoptionPlan,
  observationSchema,
  reconcile,
} from "../src/reconcile.ts";
import {
  applyImport,
  loadState,
  withLock,
  writePrivate,
} from "../src/store.ts";
import { inspectTakeout, MAX_JSON } from "../src/takeout.ts";

const fixture = new URL("./fixtures/takeout.synthetic.json", import.meta.url);
const raw = await readFile(fixture);
const records = JSON.parse(raw.toString()).subscriptions;
const initial = identify(records);
const base: State = {
  schemaVersion: 1,
  initialSource: "authoritative-takeout",
  initialDigest: hash("fixture"),
  imports: [],
  initial,
  managed: [],
};
async function temp(t: { after: (fn: () => Promise<void>) => void }) {
  const root = await mkdtemp(join(tmpdir(), "alerts-test-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  return root;
}
async function zip(
  path: string,
  entries: { name: string; data: Buffer; mode?: number }[],
) {
  const archive = new ZipFile();
  for (const e of entries) archive.addBuffer(e.data, e.name, { mode: e.mode });
  const chunks: Buffer[] = [];
  archive.outputStream.on("data", (b: Buffer) => chunks.push(b));
  const finished = new Promise<Buffer>((res, rej) => {
    archive.outputStream.on("end", () => res(Buffer.concat(chunks)));
    archive.outputStream.on("error", rej);
  });
  archive.end();
  await writeFile(path, await finished);
}
const target = "Takeout/Alerts/ALERTS-SUBSCRIPTIONS.JSON";
test("actual-schema fixture preserves nine subscriptions and unusual delivery settings", async () => {
  const result = await inspectTakeout(fixture.pathname);
  assert.equal(result.records.length, 9);
  assert.deepEqual(
    result.records.map((r) => r.record),
    records,
  );
  assert.equal(
    result.records.filter((r) => r.record.deliveryFrequency === "HOURLY")
      .length,
    1,
  );
  assert.equal(
    result.records.filter((r) => r.record.deliveryTime?.hourOfDay === -3)
      .length,
    6,
  );
  assert.equal(
    result.records.every(
      (r) => r.record.country === "US" && !r.record.applyRegionRestrict,
    ),
    true,
  );
});
test("ZIP and JSON yield identical identities and exact snapshot bytes", async (t) => {
  const root = await temp(t),
    path = join(root, "takeout.zip");
  await zip(path, [{ name: target, data: raw }]);
  const result = await inspectTakeout(path);
  assert.deepEqual(result, await inspectTakeout(fixture.pathname));
  await applyImport(join(root, "state"), result);
  assert.deepEqual(
    await readFile(join(root, "state/snapshots", result.digest + ".json")),
    raw,
  );
});
test("same import is byte-idempotent and later exports do not replace initial truth", async (t) => {
  const root = await temp(t),
    stateDir = join(root, "state"),
    a = await inspectTakeout(fixture.pathname);
  await applyImport(stateDir, a);
  const before = await readFile(join(stateDir, "state.json"));
  assert.equal((await applyImport(stateDir, a)).changed, false);
  assert.deepEqual(await readFile(join(stateDir, "state.json")), before);
  const path = join(root, "new.json");
  await writeFile(
    path,
    JSON.stringify({
      subscriptions: [{ query: "changed", future: { opaque: true } }],
    }),
  );
  await applyImport(stateDir, await inspectTakeout(path));
  const state = (await loadState(stateDir))!;
  assert.equal(state.imports.length, 2);
  assert.deepEqual(state.initial, a.records);
  assert.equal(state.initialDigest, a.digest);
  assert.equal((await stat(join(stateDir, "state.json"))).mode & 0o777, 0o600);
  assert.equal((await stat(stateDir)).mode & 0o777, 0o700);
});
test("unknown fields survive, stable identities ignore key ordering, and duplicates remain separate", async (t) => {
  const root = await temp(t),
    path = join(root, "future.json");
  const r = {
    query: "synthetic",
    deliveryTime: {
      timezoneCode: "Etc/GMT",
      hourOfDay: -3,
      dayOfWeek: 0,
      future: true,
    },
    future: { nested: [1, 2] },
  };
  await writeFile(
    path,
    JSON.stringify({ subscriptions: [r, r], futureRoot: true }),
  );
  const result = await inspectTakeout(path);
  assert.deepEqual(result.records[0]!.record, r);
  assert.notEqual(result.records[0]!.id, result.records[1]!.id);
  assert.equal(duplicateGroups(result.records).length, 1);
  assert.equal(hash({ a: 1, b: 2 }), hash({ b: 2, a: 1 }));
  assert.throws(
    () =>
      adopt(
        { ...base, initial: result.records },
        adoptionPlan({ ...base, initial: result.records }).digest,
      ),
    /Ambiguous/,
  );
});
test("invalid schema, invalid UTF-8, excessive JSON, bad ZIP, and absent entries fail", async (t) => {
  const root = await temp(t),
    path = join(root, "bad");
  for (const data of [
    Buffer.from("{bad"),
    Buffer.from('{"subscriptions":[{"query":44}]}'),
    Buffer.from([0xff]),
    Buffer.alloc(MAX_JSON + 1, 32),
    Buffer.from("PKbad"),
  ]) {
    await writeFile(path, data);
    await assert.rejects(inspectTakeout(path));
  }
  await zip(path, [{ name: "other.json", data: raw }]);
  await assert.rejects(inspectTakeout(path), /missing/);
});
test("duplicate target entries, ZIP symlinks, traversal, excessive inflation, and CRC damage fail", async (t) => {
  const root = await temp(t),
    path = join(root, "bad.zip");
  await zip(path, [
    { name: target, data: raw },
    { name: target, data: raw },
  ]);
  await assert.rejects(inspectTakeout(path));
  await zip(path, [{ name: target, data: raw, mode: 0o120777 }]);
  await assert.rejects(inspectTakeout(path));
  await zip(path, [{ name: target, data: Buffer.alloc(MAX_JSON + 1, 32) }]);
  await assert.rejects(inspectTakeout(path));
  await zip(path, [
    { name: "xx/evil", data: raw },
    { name: target, data: raw },
  ]);
  let bytes = await readFile(path);
  bytes = Buffer.from(
    bytes.toString("latin1").replaceAll("xx/evil", "../evil"),
    "latin1",
  );
  await writeFile(path, bytes);
  await assert.rejects(inspectTakeout(path));
  await zip(path, [{ name: target, data: raw }]);
  bytes = await readFile(path);
  const central = bytes.indexOf(Buffer.from([0x50, 0x4b, 0x01, 0x02]));
  bytes.writeUInt32LE(0, central + 16);
  await writeFile(path, bytes);
  await assert.rejects(inspectTakeout(path));
});
test("exclusive writes, locks, corrupt state, and symlinks fail without overwrite", async (t) => {
  const root = await temp(t),
    stateDir = join(root, "local");
  await writePrivate(join(stateDir, "private"), "one", true);
  await assert.rejects(writePrivate(join(stateDir, "private"), "two", true));
  await withLock(stateDir, async () => {
    await assert.rejects(
      withLock(stateDir, async () => undefined),
      /locked/,
    );
  });
  await writeFile(join(stateDir, "state.json"), "broken");
  await assert.rejects(loadState(stateDir), /Cannot read/);
  await symlink(join(stateDir, "private"), join(stateDir, "link"));
  await assert.rejects(writePrivate(join(stateDir, "link"), "two"));
  await symlink(stateDir, join(root, "linked-dir"));
  await assert.rejects(writePrivate(join(root, "linked-dir/new"), "two"));
  assert.equal(await readFile(join(stateDir, "private"), "utf8"), "one");
});
test("candidate YAML is draft, lossless, and ignores conflicting defaults for imports", () => {
  const c = candidateConfig(base);
  c.defaults = {
    deliveryMethod: "RSS",
    country: "GB",
    applyRegionRestrict: true,
  };
  const desired = resolveConfig(c, base);
  assert.equal(desired.length, 9);
  assert.equal(
    desired.every((r) => !r.enabled),
    true,
  );
  assert.deepEqual(
    desired.map((d) => d.record),
    records,
  );
  c.topics[0]!.queries[0]!.settings = { deliveryFrequency: "WEEKLY" };
  assert.equal(resolveConfig(c, base)[0]!.record.deliveryFrequency, "WEEKLY");
  assert.equal(resolveConfig(c, base)[0]!.record.deliveryTime?.hourOfDay, -3);
});
test("strict YAML rejects typos, duplicate keys, aliases, unreviewed activation, and repeated ownership", async (t) => {
  const root = await temp(t),
    path = join(root, "bad.yaml");
  for (const text of [
    "schemaVersion: 1\nschemaVersion: 1\ntopics: []",
    "schemaVersion: 1\ntopcis: []",
    "a: &a [*a]\nschemaVersion: 1\ntopics: *a",
  ]) {
    await writeFile(path, text);
    await assert.rejects(readConfig(path));
  }
  const c = candidateConfig(base);
  c.topics[0]!.queries[0]!.status = "active";
  assert.throws(() => configSchema.parse(c));
  c.topics[0]!.queries[0]!.status = "draft";
  c.topics[1]!.queries[0]!.inherit = c.topics[0]!.queries[0]!.inherit;
  assert.throws(() => configSchema.parse(c));
  const d = candidateConfig(base);
  d.topics[0]!.queries[0]!.inherit = "import-" + "0".repeat(64) + "-1";
  assert.throws(() => resolveConfig(d, base), /Unknown/);
});
test("new active alerts require manual approval and complete delivery destination", () => {
  const c = configSchema.parse({
    schemaVersion: 1,
    topics: [
      {
        id: "new",
        name: "New",
        intent: "Test",
        queries: [
          {
            id: "one",
            expression: "test",
            status: "active",
            review: {
              approved: true,
              reviewer: "local-user",
              at: "2026-11-23T00:00:00Z",
            },
          },
        ],
      },
    ],
  });
  assert.throws(() => resolveConfig(c, base), /delivery/);
  c.defaults = {
    deliveryMethod: "EMAIL",
    emailAddress: "recipient@example.invalid",
    deliveryFrequency: "DAILY",
  };
  assert.equal(resolveConfig(c, base)[0]!.record.deliveryFrequency, "DAILY");
});
test("adoption approval is bound to exact plan and does not change Google or auto-activate drafts", () => {
  const p = adoptionPlan(base);
  assert.equal(p.eligible.length, 9);
  assert.throws(() => adopt(base, "wrong"), /Approval/);
  const state = adopt(base, p.digest);
  assert.equal(state.managed.length, 9);
  assert.deepEqual(state.initial, base.initial);
  assert.equal(adoptionPlan(state).eligible.length, 0);
  assert.equal(
    resolveConfig(candidateConfig(state), state).some((d) => d.enabled),
    false,
  );
});
test("three-way plans: adopt, unchanged, update, missing, conflict, pause, removal proposal", () => {
  const c = candidateConfig(base);
  for (const t of c.topics)
    for (const q of t.queries) {
      q.status = "active";
      q.review = {
        approved: true,
        reviewer: "user",
        at: "2026-11-23T00:00:00Z",
      };
    }
  const desired = resolveConfig(configSchema.parse(c), base);
  assert.equal(
    reconcile(base, desired).operations.filter((o) => o.action === "adopt")
      .length,
    9,
  );
  const state = adopt(base, adoptionPlan(base).digest);
  assert.equal(
    reconcile(state, desired).operations.every((o) => o.action === "unchanged"),
    true,
  );
  const changed = structuredClone(desired);
  changed[0]!.record.query = "new expression";
  assert.equal(reconcile(state, changed).operations[0]!.action, "update");
  const observation = observationSchema.parse({
    schemaVersion: 1,
    origin: "browser",
    accountVerified: true,
    capturedAt: "2026-11-23T00:00:00Z",
    alerts: initial.map((r, i) => ({
      providerId: `row-${i}`,
      record: r.record,
    })),
  });
  state.managed[0]!.providerId = "row-0";
  observation.alerts[0]!.record = {
    ...observation.alerts[0]!.record,
    query: "outside change",
  };
  assert.equal(
    reconcile(state, changed, observation).operations[0]!.action,
    "conflict",
  );
  observation.alerts.shift();
  assert.equal(
    reconcile(state, changed, observation).operations[0]!.action,
    "missing",
  );
  assert.equal(
    reconcile(state, desired.slice(1)).operations.some(
      (o) => o.action === "delete-proposed",
    ),
    true,
  );
  desired[0]!.enabled = false;
  assert.equal(reconcile(state, desired).operations[0]!.action, "paused");
});
test("duplicate observed identities and duplicate desired targets are conflicts", () => {
  const c = candidateConfig(base),
    desired = resolveConfig(c, base);
  desired[0]!.enabled = true;
  const state = adopt(base, adoptionPlan(base).digest);
  const obs = observationSchema.parse({
    schemaVersion: 1,
    origin: "browser",
    accountVerified: true,
    capturedAt: "2026-11-23T00:00:00Z",
    alerts: [{ record: records[0] }, { record: records[0] }],
  });
  assert.equal(
    reconcile(state, desired, obs).operations[0]!.action,
    "conflict",
  );
  desired[1]!.enabled = true;
  desired[1]!.record = desired[0]!.record;
  assert.equal(reconcile(state, desired).operations[0]!.action, "conflict");
});
test("CLI dry-run creates no state, output withholds private fields, and --apply sync fails closed", async (t) => {
  const root = await temp(t),
    stateDir = join(root, "state"),
    cli = new URL("../src/cli.ts", import.meta.url).pathname;
  const run = (args: string[]) =>
    execFileSync(process.execPath, [cli, ...args, "--state-dir", stateDir], {
      encoding: "utf8",
    });
  const result = JSON.parse(
    run(["import", "--from-takeout", fixture.pathname]),
  );
  assert.equal(result.applied, false);
  await assert.rejects(stat(stateDir));
  run(["import", "--from-takeout", fixture.pathname, "--apply"]);
  run(["topics", "--apply"]);
  run(["validate"]);
  const output = run(["plan"]);
  for (const r of records) {
    assert.equal(output.includes(r.query), false);
    assert.equal(output.includes(r.emailAddress), false);
  }
  const blocked = spawnSync(
    process.execPath,
    [cli, "sync", "--apply", "--state-dir", stateDir],
    { encoding: "utf8" },
  );
  assert.equal(blocked.status, 1);
  assert.match(blocked.stderr, /Live sync is disabled/);
  assert.equal((await loadState(stateDir))!.managed.length, 0);
});
test("tampered or missing immutable snapshots fail re-import rather than hide corruption", async (t) => {
  const root = await temp(t),
    result = await inspectTakeout(fixture.pathname);
  await applyImport(root, result);
  const path = join(root, "snapshots", result.digest + ".json");
  await writeFile(path, "tampered");
  await assert.rejects(applyImport(root, result), /Snapshot integrity/);
  await rm(path);
  await assert.rejects(applyImport(root, result), /Snapshot integrity/);
});
test("state validation rejects altered initial identity and duplicate owners", async (t) => {
  const root = await temp(t),
    result = await inspectTakeout(fixture.pathname);
  await applyImport(root, result);
  const state = (await loadState(root))!;
  state.initial[0]!.record.query = "untracked change";
  await writeFile(join(root, "state.json"), JSON.stringify(state));
  await assert.rejects(loadState(root), /Cannot read/);
});
test("new reviewed queries produce create or unmanaged without claiming ownership", () => {
  const desired = [
    {
      key: "new/one",
      enabled: true,
      record: { query: "new unique expression" },
    },
  ];
  assert.equal(reconcile(base, desired).operations[0]!.action, "create");
  desired[0]!.record = { query: records[0].query, ...records[0] };
  assert.equal(reconcile(base, desired).operations[0]!.action, "unmanaged");
  assert.equal(base.managed.length, 0);
});
test("observed convergence is unchanged; remote changes without stable identity are never guessed", () => {
  const state = adopt(base, adoptionPlan(base).digest);
  const desired = resolveConfig(candidateConfig(base), base);
  desired[0]!.enabled = true;
  desired[0]!.record = {
    ...desired[0]!.record,
    query: "reviewed changed query",
  };
  state.managed[0]!.providerId = "verified-ui-id";
  const observed = observationSchema.parse({
    schemaVersion: 1,
    origin: "browser",
    accountVerified: true,
    capturedAt: "2026-11-23T00:00:00Z",
    alerts: [{ providerId: "verified-ui-id", record: desired[0]!.record }],
  });
  assert.equal(
    reconcile(state, desired, observed).operations[0]!.action,
    "unchanged",
  );
  delete state.managed[0]!.providerId;
  assert.equal(
    reconcile(state, desired, observed).operations[0]!.action,
    "missing",
  );
});
