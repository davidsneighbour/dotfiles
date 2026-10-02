import assert from "node:assert/strict";
import { test } from "node:test";
import {
  aggregateStatus,
  commitDate,
  commitIdentity,
  commitItemPath,
} from "../src/model.ts";

test("full object identity rejects abbreviations and path injection", () => {
  assert.equal(
    commitIdentity("sha1", "a".repeat(40)),
    `sha1:${"a".repeat(40)}`,
  );
  assert.equal(
    commitIdentity("sha256", "b".repeat(64)),
    `sha256:${"b".repeat(64)}`,
  );
  for (const hash of ["abc123", "../commit", "A".repeat(40), "a".repeat(64)]) {
    assert.throws(() => commitIdentity("sha1", hash));
  }
});

test("Bangkok midnight and year boundaries define the folder date", () => {
  assert.equal(commitDate("2026-12-31T16:59:59Z"), "2026-12-31");
  assert.equal(commitDate("2026-12-31T17:00:00Z"), "2027-01-01");
  assert.equal(commitDate("2027-01-01T00:00:00+07:00"), "2027-01-01");
  assert.equal(
    commitItemPath({
      hash: "a".repeat(40),
      object_format: "sha1",
      committed_at: "2026-12-31T17:00:00Z",
    }),
    `23 Eventlog/Github/items/2027/01/01/${"a".repeat(40)}.md`,
  );
});

test("explicit offsets and valid timezones are required", () => {
  assert.throws(() => commitDate("2026-10-02T00:00:00"));
  assert.throws(() => commitDate("2026-99-02T00:00:00Z"));
  assert.throws(() => commitDate("2026-02-30T00:00:00Z"));
  assert.throws(() => commitDate("2026-10-02T00:00:00Z", "Invalid/Zone"));
});

test("shared history stays reachable while any repository retains the object", () => {
  const observation = (status: "reachable" | "unreachable" | "unknown") => ({
    repository_id: "local-test",
    status,
  });
  assert.equal(
    aggregateStatus([observation("unreachable"), observation("reachable")]),
    "reachable",
  );
  assert.equal(
    aggregateStatus([observation("unreachable"), observation("unknown")]),
    "unknown",
  );
  assert.equal(aggregateStatus([observation("unreachable")]), "unreachable");
  assert.equal(aggregateStatus([]), "unknown");
});
