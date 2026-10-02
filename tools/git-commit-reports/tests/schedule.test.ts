import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";
import { dueDay, SCHEDULE, scheduledSync } from "../src/schedule.ts";
import type { SyncResult } from "../src/sync.ts";
import { fixture } from "./fixtures.ts";

test("daily cycle starts at 08:00 Bangkok, including year boundaries", () => {
  assert.equal(dueDay(new Date("2026-01-01T07:59:59+07:00")), "2025-12-31");
  assert.equal(dueDay(new Date("2026-01-01T08:00:00+07:00")), "2026-01-01");
  assert.throws(() => dueDay(new Date("invalid")), /Invalid/);
});
test("scheduler refuses a missing vault without creating it", async (t) => {
  const f = await fixture(t);
  const missing = `${f.vault}/missing`;
  await assert.rejects(scheduledSync({ vault: missing }), { code: "ENOENT" });
  await assert.rejects(readFile(`${missing}/${SCHEDULE}`), { code: "ENOENT" });
});
test("successful cycle skips duplicates, failed cycles retry, and dry runs never complete a cycle", async (t) => {
  const f = await fixture(t);
  let calls = 0;
  const now = new Date("2026-10-02T10:00:00+07:00");
  const complete: SyncResult = {
    repositories: [],
    failed: 0,
    dryRun: false,
    recovered: false,
  };
  const run = async () => {
    calls++;
    return complete;
  };
  await scheduledSync({ vault: f.vault, now, ifDue: true, dryRun: true }, run);
  await assert.rejects(readFile(`${f.vault}/${SCHEDULE}`), { code: "ENOENT" });
  await scheduledSync({ vault: f.vault, now, ifDue: true }, async () => ({
    ...complete,
    failed: 1,
  }));
  await assert.rejects(readFile(`${f.vault}/${SCHEDULE}`), { code: "ENOENT" });
  await scheduledSync({ vault: f.vault, now, ifDue: true }, run);
  assert.equal(
    await scheduledSync({ vault: f.vault, now, ifDue: true }, run),
    undefined,
  );
  assert.equal(calls, 2);
  await scheduledSync(
    { vault: f.vault, now: new Date("2026-10-03T08:00:00+07:00"), ifDue: true },
    run,
  );
  assert.equal(calls, 3);
});
test("concurrent scheduled writers cannot start a second sync", async (t) => {
  const f = await fixture(t);
  let release: () => void = () => {
    throw new Error("Unexpected release");
  };
  let started: () => void = () => {
    throw new Error("Unexpected start");
  };
  const ready = new Promise<void>((resolve) => {
    started = resolve;
  });
  const wait = new Promise<void>((resolve) => {
    release = resolve;
  });
  const first = scheduledSync({ vault: f.vault }, async () => {
    started();
    await wait;
    return { repositories: [], failed: 0, dryRun: false, recovered: false };
  });
  await ready;
  await assert.rejects(scheduledSync({ vault: f.vault }), /already running/);
  release();
  await first;
});
