#!/usr/bin/env -S node --experimental-strip-types

import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { parseBackupTomlConfig } from "../backup-runner.ts";

const testDirectory = dirname(fileURLToPath(import.meta.url));
const fixturesDirectory = join(testDirectory, "fixtures");

async function readFixture(name: string): Promise<string> {
  return readFile(join(fixturesDirectory, name), "utf8");
}

async function assertRejectsWithMessage(
  fixtureName: string,
  expectedMessage: RegExp,
): Promise<void> {
  const content = await readFixture(fixtureName);

  assert.throws(
    () => parseBackupTomlConfig(content, fixtureName),
    expectedMessage,
  );
}

const validConfig = parseBackupTomlConfig(
  await readFixture("backup-valid.toml"),
  "backup-valid.toml",
);

assert.deepEqual(validConfig, {
  enabled: true,
  name: "portainer",
  mode: "compose-copy",
  service_root: ".",
  compose_file: "docker-compose.yml",
  data_paths: ["data", "uploads"],
  pre_command: "echo Starting ${name}",
  post_command: "echo Finished ${archive}",
  upload_command: "rclone copy ${archive} remote:docker-backups/${host}/",
  stop_timeout_seconds: 30,
  compression: "tar.gz",
  ignore_missing_paths: false,
});

const missingKeysConfig = parseBackupTomlConfig(
  await readFixture("backup-missing-keys.toml"),
  "backup-missing-keys.toml",
);

assert.deepEqual(missingKeysConfig, {});

const emptyStringsConfig = parseBackupTomlConfig(
  await readFixture("backup-empty-strings.toml"),
  "backup-empty-strings.toml",
);

assert.equal(emptyStringsConfig.name, "");
assert.equal(emptyStringsConfig.service_root, "");
assert.equal(emptyStringsConfig.compose_file, "");
assert.deepEqual(emptyStringsConfig.data_paths, ["", "data"]);
assert.equal(emptyStringsConfig.pre_command, "");
assert.equal(emptyStringsConfig.post_command, "");
assert.equal(emptyStringsConfig.upload_command, "");

await assertRejectsWithMessage("backup-invalid.toml", /Invalid TOML config/u);
await assertRejectsWithMessage(
  "backup-invalid-data-paths.toml",
  /data_paths must be an array of strings/u,
);

console.log("backup-runner TOML config fixtures passed");
