#!/usr/bin/env node

import { execFile } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { promisify } from "node:util";
import { parse as parseToml } from "smol-toml";

type TargetFormat = "json" | "text-line";

interface JsonTarget {
  path: string;
  format: "json";
  pointer: string;
}

interface TextLineTarget {
  path: string;
  format: "text-line";
  pattern: string;
  replacement: string;
}

type Target = JsonTarget | TextLineTarget;

const SCRIPT_NAME = path.basename(process.argv[1] ?? "bump-versions.ts");
const DEFAULT_CONFIG_PATH = path.join(process.cwd(), ".version-targets.toml");
const VERSION_PATTERN = /^\d+\.\d+\.\d+(?:[-+].+)?$/;
const execFileAsync = promisify(execFile);

function usage(): string {
  return `
Usage:
  ${SCRIPT_NAME} --version <X.Y.Z> [--config <path>] [--dry-run] [--help]

Writes the given version into every file listed in .version-targets.toml.
package.json itself is bumped natively by release-it and is not one of
these targets.

Options:
  --version <X.Y.Z>  Required. The version to write.
  --config <path>    Path to the TOML target list.
                     Default: ${DEFAULT_CONFIG_PATH}
  --dry-run          Print what would change without writing files.
  --help             Show this help.
`.trim();
}

interface CliOptions {
  version: string;
  configPath: string;
  dryRun: boolean;
  help: boolean;
}

function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = {
    version: "",
    configPath: DEFAULT_CONFIG_PATH,
    dryRun: false,
    help: false,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];

    switch (arg) {
      case "--help":
        options.help = true;
        break;

      case "--dry-run":
        options.dryRun = true;
        break;

      case "--version": {
        const value = argv[index + 1];
        if (!value) {
          throw new Error("--version requires a value");
        }
        options.version = value;
        index += 1;
        break;
      }

      case "--config": {
        const value = argv[index + 1];
        if (!value) {
          throw new Error("--config requires a value");
        }
        options.configPath = path.resolve(value);
        index += 1;
        break;
      }

      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

function isTargetFormat(value: unknown): value is TargetFormat {
  return value === "json" || value === "text-line";
}

function validateTargets(rawConfig: unknown): Target[] {
  if (!rawConfig || typeof rawConfig !== "object") {
    throw new Error("Config must be an object");
  }

  const configObject = rawConfig as Record<string, unknown>;
  const rawTargets = configObject["target"];

  if (!Array.isArray(rawTargets)) {
    throw new Error("Config must contain a [[target]] array");
  }

  return rawTargets.map((item, index) => {
    if (!item || typeof item !== "object") {
      throw new Error(`target[${index}] must be an object`);
    }

    const targetObject = item as Record<string, unknown>;
    const targetPath = targetObject["path"];
    const format = targetObject["format"];

    if (typeof targetPath !== "string" || targetPath.trim() === "") {
      throw new Error(`target[${index}].path must be a non-empty string`);
    }

    if (!isTargetFormat(format)) {
      throw new Error(`target[${index}].format must be "json" or "text-line"`);
    }

    if (format === "json") {
      const pointer = targetObject["pointer"];
      if (typeof pointer !== "string" || pointer.trim() === "") {
        throw new Error(
          `target[${index}].pointer must be a non-empty string for format "json"`,
        );
      }
      return { path: targetPath, format, pointer };
    }

    const pattern = targetObject["pattern"];
    const replacement = targetObject["replacement"];

    if (typeof pattern !== "string" || pattern.trim() === "") {
      throw new Error(
        `target[${index}].pattern must be a non-empty string for format "text-line"`,
      );
    }
    if (typeof replacement !== "string" || replacement.trim() === "") {
      throw new Error(
        `target[${index}].replacement must be a non-empty string for format "text-line"`,
      );
    }

    return { path: targetPath, format, pattern, replacement };
  });
}

async function loadTargets(configPath: string): Promise<Target[]> {
  const content = await readFile(configPath, "utf8");
  const parsed = parseToml(content);
  return validateTargets(parsed);
}

function setAtPointer(
  root: Record<string, unknown>,
  pointer: string,
  value: string,
): void {
  const keys = pointer.split(".");
  let cursor: Record<string, unknown> = root;

  for (let index = 0; index < keys.length - 1; index += 1) {
    const key = keys[index] as string;
    const next = cursor[key];
    if (!next || typeof next !== "object") {
      throw new Error(`Path "${pointer}" does not exist in the JSON file`);
    }
    cursor = next as Record<string, unknown>;
  }

  const lastKey = keys[keys.length - 1] as string;
  if (!(lastKey in cursor)) {
    throw new Error(`Path "${pointer}" does not exist in the JSON file`);
  }

  cursor[lastKey] = value;
}

async function applyJsonTarget(
  target: JsonTarget,
  version: string,
  dryRun: boolean,
): Promise<void> {
  const absolutePath = path.resolve(target.path);
  const content = await readFile(absolutePath, "utf8");
  const parsed: unknown = JSON.parse(content);

  if (!parsed || typeof parsed !== "object") {
    throw new Error(`${target.path} does not contain a JSON object`);
  }

  setAtPointer(parsed as Record<string, unknown>, target.pointer, version);

  const updated = `${JSON.stringify(parsed, null, 2)}\n`;

  if (dryRun) {
    console.log(
      `[dry-run] Would set ${target.path}#${target.pointer} = "${version}"`,
    );
    return;
  }

  await writeFile(absolutePath, updated, "utf8");
  console.log(`Updated ${target.path}#${target.pointer} -> ${version}`);
}

async function applyTextLineTarget(
  target: TextLineTarget,
  version: string,
  dryRun: boolean,
): Promise<void> {
  const absolutePath = path.resolve(target.path);
  const content = await readFile(absolutePath, "utf8");
  const lines = content.split("\n");
  const regex = new RegExp(target.pattern);
  const replacementLine = target.replacement.replace("{version}", version);

  let matched = false;
  const updatedLines = lines.map((line) => {
    if (regex.test(line)) {
      matched = true;
      return replacementLine;
    }
    return line;
  });

  if (!matched) {
    throw new Error(
      `Pattern ${target.pattern} did not match any line in ${target.path}`,
    );
  }

  if (dryRun) {
    console.log(
      `[dry-run] Would rewrite matching line(s) in ${target.path} to: ${replacementLine}`,
    );
    return;
  }

  await writeFile(absolutePath, updatedLines.join("\n"), "utf8");
  console.log(`Updated ${target.path} -> ${replacementLine}`);
}

async function gitAdd(files: string[]): Promise<void> {
  if (files.length === 0) {
    return;
  }
  await execFileAsync("git", ["add", ...files]);
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv);

  if (options.help) {
    console.log(usage());
    return;
  }

  if (!options.version) {
    console.error(usage());
    throw new Error("--version is required");
  }

  if (!VERSION_PATTERN.test(options.version)) {
    throw new Error(
      `--version "${options.version}" does not look like a version (expected X.Y.Z, optionally with -pre/+build)`,
    );
  }

  const targets = await loadTargets(options.configPath);
  const touchedFiles: string[] = [];

  for (const target of targets) {
    if (target.format === "json") {
      await applyJsonTarget(target, options.version, options.dryRun);
    } else {
      await applyTextLineTarget(target, options.version, options.dryRun);
    }
    touchedFiles.push(target.path);
  }

  if (!options.dryRun) {
    await gitAdd(touchedFiles);
  }
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`${SCRIPT_NAME}: ${message}`);
  process.exitCode = 1;
});
