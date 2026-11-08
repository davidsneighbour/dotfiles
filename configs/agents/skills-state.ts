#!/usr/bin/env node
/**
 * Compare a skills CLI project lockfile (`skills-lock.json`) with the
 * installed skill directories.
 *
 * The content hash reproduces `computeSkillFolderHash` from the `skills` CLI
 * (version pinned in install-skills.sh): SHA-256 over all regular files,
 * sorted by relative path with `localeCompare`, hashing each relative path
 * followed by the file content. `.git` and `node_modules` directories and
 * symbolic links are skipped. Re-verify this when the pinned CLI changes.
 *
 * Output (stdout): one tab-separated record per line.
 *   locked<TAB>NAME<TAB>SOURCE<TAB>STATE   STATE: ok | missing | modified | not-a-directory
 *   unlocked<TAB>NAME<TAB>-<TAB>-          a directory below --skills-dir without a lockfile entry
 *
 * Exit codes: 0 records printed, 1 invalid lockfile or read error, 2 usage error.
 */

import { createHash } from "node:crypto";
import type { Dirent } from "node:fs";
import { lstat, readdir, readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

interface LockEntry {
  source: string;
  computedHash: string;
}

interface HashedFile {
  relativePath: string;
  content: Buffer;
}

const SCRIPT_NAME = path.basename(process.argv[1] ?? "skills-state.ts");
const NAME_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const HASH_PATTERN = /^[0-9a-f]{64}$/;

function usage(): string {
  return `Usage: ${SCRIPT_NAME} --lockfile PATH --skills-dir PATH [--verbose]
       ${SCRIPT_NAME} --hash DIRECTORY
       ${SCRIPT_NAME} --help

Validate a skills CLI project lockfile and compare every entry with the
installed skill directory. Prints tab-separated records on stdout.

Options:
  --lockfile PATH    The project skills-lock.json.
  --skills-dir PATH  The canonical skill directory (for example .agents/skills).
  --hash DIRECTORY   Print the computedHash of one skill directory and exit.
  --verbose          Print every hashed skill on stderr.
  --help             Show this help.
`;
}

function fail(message: string, code = 1): never {
  process.stderr.write(`${SCRIPT_NAME}: ${message}\n`);
  process.exit(code);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isMissing(error: unknown): boolean {
  return isRecord(error) && error["code"] === "ENOENT";
}

function clean(value: string): string {
  return value.replace(/[\t\r\n]/g, " ");
}

async function collectFiles(
  baseDir: string,
  currentDir: string,
  results: HashedFile[],
): Promise<void> {
  const entries: Dirent[] = await readdir(currentDir, { withFileTypes: true });
  await Promise.all(
    entries.map(async (entry) => {
      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === ".git" || entry.name === "node_modules") {
          return;
        }
        await collectFiles(baseDir, fullPath, results);
      } else if (entry.isFile()) {
        results.push({
          relativePath: path.relative(baseDir, fullPath).split("\\").join("/"),
          content: await readFile(fullPath),
        });
      }
    }),
  );
}

async function hashSkillFolder(skillDir: string): Promise<string> {
  const files: HashedFile[] = [];
  await collectFiles(skillDir, skillDir, files);
  files.sort((a, b) => a.relativePath.localeCompare(b.relativePath));
  const hash = createHash("sha256");
  for (const file of files) {
    hash.update(file.relativePath);
    hash.update(file.content);
  }
  return hash.digest("hex");
}

function parseLockfile(raw: string, lockfile: string): Map<string, LockEntry> {
  let data: unknown;
  try {
    data = JSON.parse(raw);
  } catch (error) {
    fail(
      `${lockfile} is not valid JSON: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
  if (!isRecord(data)) {
    fail(`${lockfile} must contain a JSON object.`);
  }
  const version = data["version"];
  const skills = data["skills"];
  if (version !== 1) {
    fail(
      `${lockfile} has lockfile version ${String(version)}; only version 1 is supported. Check the pinned skills CLI version.`,
    );
  }
  if (!isRecord(skills)) {
    fail(`${lockfile} has no "skills" object.`);
  }

  const entries = new Map<string, LockEntry>();
  const folded = new Map<string, string>();
  const problems: string[] = [];

  for (const [name, value] of Object.entries(skills)) {
    if (!NAME_PATTERN.test(name)) {
      problems.push(`"${name}" is not a safe skill directory name`);
      continue;
    }
    const other = folded.get(name.toLowerCase());
    if (other !== undefined) {
      problems.push(`"${name}" and "${other}" collide as directory names`);
      continue;
    }
    folded.set(name.toLowerCase(), name);
    const source = isRecord(value) ? value["source"] : undefined;
    const computedHash = isRecord(value) ? value["computedHash"] : undefined;
    if (typeof source !== "string" || typeof computedHash !== "string") {
      problems.push(
        `"${name}" needs string "source" and "computedHash" fields`,
      );
      continue;
    }
    if (!HASH_PATTERN.test(computedHash)) {
      problems.push(`"${name}" has a malformed computedHash`);
      continue;
    }
    entries.set(name, { source, computedHash });
  }

  if (problems.length > 0) {
    fail(`${lockfile} is not usable:\n  ${problems.join("\n  ")}`);
  }
  return entries;
}

async function main(): Promise<void> {
  let lockfile = "";
  let skillsDir = "";
  let hashDir = "";
  let verbose = false;
  const args = process.argv.slice(2);

  while (args.length > 0) {
    const arg = args.shift();
    switch (arg) {
      case "--help":
        process.stdout.write(usage());
        return;
      case "--hash":
        hashDir = args.shift() ?? "";
        if (hashDir === "") {
          fail("--hash needs a directory.", 2);
        }
        break;
      case "--lockfile":
        lockfile = args.shift() ?? "";
        break;
      case "--skills-dir":
        skillsDir = args.shift() ?? "";
        break;
      case "--verbose":
        verbose = true;
        break;
      default:
        process.stderr.write(usage());
        fail(`unknown option: ${String(arg)}`, 2);
    }
  }
  if (hashDir !== "") {
    try {
      process.stdout.write(`${await hashSkillFolder(hashDir)}\n`);
    } catch (error) {
      fail(
        `cannot hash ${hashDir}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
    return;
  }
  if (lockfile === "" || skillsDir === "") {
    process.stderr.write(usage());
    fail("--lockfile and --skills-dir are required.", 2);
  }

  let raw: string;
  try {
    raw = await readFile(lockfile, "utf8");
  } catch (error) {
    fail(
      `cannot read ${lockfile}: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
  const entries = parseLockfile(raw, lockfile);
  const lines: string[] = [];

  for (const [name, entry] of [...entries].sort(([a], [b]) =>
    a.localeCompare(b),
  )) {
    const skillDir = path.join(skillsDir, name);
    let state = "ok";
    try {
      const stats = await lstat(skillDir);
      if (!stats.isDirectory()) {
        state = "not-a-directory";
      } else {
        const actual = await hashSkillFolder(skillDir);
        if (actual !== entry.computedHash) {
          state = "modified";
        }
        if (verbose) {
          process.stderr.write(
            `${name}: locked ${entry.computedHash}, actual ${actual}\n`,
          );
        }
      }
    } catch (error) {
      if (!isMissing(error)) {
        fail(
          `cannot inspect ${skillDir}: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
      state = "missing";
    }
    lines.push(["locked", name, clean(entry.source), state].join("\t"));
  }

  let installed: Dirent[] = [];
  try {
    installed = await readdir(skillsDir, { withFileTypes: true });
  } catch (error) {
    if (!isMissing(error)) {
      fail(
        `cannot read ${skillsDir}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }
  for (const entry of installed.sort((a, b) => a.name.localeCompare(b.name))) {
    if (!entries.has(entry.name)) {
      lines.push(["unlocked", clean(entry.name), "-", "-"].join("\t"));
    }
  }

  if (lines.length > 0) {
    process.stdout.write(`${lines.join("\n")}\n`);
  }
}

await main();
