#!/usr/bin/env node

import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { promisify } from "node:util";

interface Finding {
  file: string;
  line: number;
  value: string;
}

const SCRIPT_NAME = path.basename(process.argv[1] ?? "lint-log-filenames.ts");
const SUPPORTED_EXTENSIONS = new Set([
  ".bash",
  ".cjs",
  ".js",
  ".json",
  ".jsonc",
  ".mjs",
  ".sh",
  ".toml",
  ".ts",
  ".yaml",
  ".yml",
]);
const LOG_PATH_PATTERN =
  /(?:^|["'=\s])((?:~|\$\{?HOME\}?|\/var|\/tmp|\.?\/?logs?|[^"'`\s]*\.logs?)[^"'`\s]*?\/[^"'`\s]*?\.log)\b/g;
const DATE_TOKEN_PATTERN =
  /(?:YYYYMM|\d{6,8}|%[YymdHMS]|date\s+\+|\$\([^)]*date|[$][{(]?(?:DATE|NOW|TIMESTAMP|ts|currentDay|timestamp)\b)/i;
const execFileAsync = promisify(execFile);

function usage(): string {
  return `
Usage:
  ${SCRIPT_NAME} [--help] [--verbose] [file...]

Checks changed source/config files for obvious static log filenames.
If no files are provided, the current staged and unstaged file changes are inspected.

Options:
  --help     Show this help output.
  --verbose  Print every inspected file.
`.trim();
}

function isSupportedFile(file: string): boolean {
  return SUPPORTED_EXTENSIONS.has(path.extname(file));
}

function isStaticLogPath(candidate: string): boolean {
  if (!candidate.endsWith(".log")) {
    return false;
  }

  if (candidate.includes("*") || candidate.includes("?")) {
    return false;
  }

  return !DATE_TOKEN_PATTERN.test(candidate);
}

async function inspectFile(file: string, verbose: boolean): Promise<Finding[]> {
  if (!isSupportedFile(file)) {
    return [];
  }

  if (verbose) {
    console.log(`Inspecting ${file}`);
  }

  const content = await readFile(file, "utf8");
  const findings: Finding[] = [];
  const lines = content.split(/\r?\n/);

  lines.forEach((line, index) => {
    for (const match of line.matchAll(LOG_PATH_PATTERN)) {
      const value = match[1];

      if (value && isStaticLogPath(value)) {
        findings.push({
          file,
          line: index + 1,
          value,
        });
      }
    }
  });

  return findings;
}

function printFinding(finding: Finding): void {
  console.error(
    `${finding.file}:${String(finding.line)}: static log filename lacks an obvious date token: ${finding.value}`,
  );
}

async function gitChangedFiles(args: string[]): Promise<string[]> {
  const { stdout } = await execFileAsync("git", args);
  return stdout
    .split(/\r?\n/)
    .map((file) => file.trim())
    .filter(Boolean);
}

async function collectDefaultFiles(): Promise<string[]> {
  const stagedFiles = await gitChangedFiles([
    "diff",
    "--cached",
    "--name-only",
    "--diff-filter=ACMR",
  ]);
  const unstagedFiles = await gitChangedFiles([
    "diff",
    "--name-only",
    "--diff-filter=ACMR",
  ]);

  return [...new Set([...stagedFiles, ...unstagedFiles])];
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  let verbose = false;
  const files: string[] = [];

  for (const arg of args) {
    switch (arg) {
      case "--help":
        console.log(usage());
        return;

      case "--verbose":
        verbose = true;
        break;

      default:
        files.push(arg);
        break;
    }
  }

  const filesToInspect = files.length > 0 ? files : await collectDefaultFiles();

  const findings = (
    await Promise.all(filesToInspect.map((file) => inspectFile(file, verbose)))
  ).flat();

  if (findings.length === 0) {
    return;
  }

  for (const finding of findings) {
    printFinding(finding);
  }

  console.error(
    "\nUse YYYYMMDD-HHMMSS.log where practical, or YYYYMM.log only when finer granularity is not practical.",
  );
  process.exitCode = 1;
}

main().catch((error: unknown) => {
  const message =
    error instanceof Error ? error.message : `Unknown error: ${String(error)}`;
  console.error(`Error: ${message}`);
  process.exitCode = 1;
});
