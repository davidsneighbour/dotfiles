#!/usr/bin/env -S node --experimental-strip-types

import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

type CliOptions = {
  dryRun: boolean;
  help: boolean;
  npmCommand: string;
  packageFilePath: string;
  verbose: boolean;
};

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const DEFAULT_PACKAGE_FILE = resolve(SCRIPT_DIR, "default-packages");
const DEFAULT_NPM_COMMAND = "npm";

function usage(): string {
  return `
Usage:
  node --experimental-strip-types configs/system/npm/install-default-packages.ts [options]

Installs every package listed in configs/system/npm/default-packages globally.
Blank lines and lines starting with "#" are ignored.

Options:
  --package-file <path>  Read packages from a different newline-delimited file.
  --npm <command>        Use a different npm-compatible command. Default: npm.
  --dry-run              Print the install command without running it.
  --verbose              Print the parsed package list before installing.
  --quiet                Disable verbose output, including DNB_VERBOSE.
  --help                 Show this help message.
`.trim();
}

function parseArgs(args: readonly string[]): CliOptions {
  const options: CliOptions = {
    dryRun: false,
    help: false,
    npmCommand: DEFAULT_NPM_COMMAND,
    packageFilePath: DEFAULT_PACKAGE_FILE,
    verbose: process.env["DNB_VERBOSE"] === "1",
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];

    switch (arg) {
      case "--dry-run":
        options.dryRun = true;
        break;

      case "--help":
        options.help = true;
        break;

      case "--npm": {
        const value = args[index + 1];

        if (!value || value.startsWith("--")) {
          throw new Error("Missing value for --npm.");
        }

        options.npmCommand = value;
        index += 1;
        break;
      }

      case "--package-file": {
        const value = args[index + 1];

        if (!value || value.startsWith("--")) {
          throw new Error("Missing value for --package-file.");
        }

        options.packageFilePath = resolve(process.cwd(), value);
        index += 1;
        break;
      }

      case "--quiet":
        options.verbose = false;
        delete process.env["DNB_VERBOSE"];
        break;

      case "--verbose":
        options.verbose = true;
        process.env["DNB_VERBOSE"] = "1";
        break;

      default:
        throw new Error(`Unknown option: ${String(arg)}`);
    }
  }

  return options;
}

function parsePackageList(content: string): string[] {
  return content
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line !== "" && !line.startsWith("#"));
}

async function readPackages(packageFilePath: string): Promise<string[]> {
  const content = await readFile(packageFilePath, "utf8");
  const packages = parsePackageList(content);

  if (packages.length === 0) {
    throw new Error(`No packages found in ${packageFilePath}.`);
  }

  return packages;
}

function quoteShellArgument(value: string): string {
  if (/^[A-Za-z0-9_./:@+-]+$/.test(value)) {
    return value;
  }

  return `'${value.replaceAll("'", "'\\''")}'`;
}

function formatCommand(command: string, args: readonly string[]): string {
  return [command, ...args].map(quoteShellArgument).join(" ");
}

async function runCommand(
  command: string,
  args: readonly string[],
): Promise<void> {
  await new Promise<void>((resolvePromise, reject) => {
    const child = spawn(command, args, {
      stdio: "inherit",
    });

    child.on("error", reject);
    child.on("close", (code, signal) => {
      if (signal) {
        reject(new Error(`${command} was terminated by signal ${signal}.`));
        return;
      }

      if (code !== 0) {
        reject(new Error(`${command} exited with status ${String(code)}.`));
        return;
      }

      resolvePromise();
    });
  });
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    console.log(usage());
    return;
  }

  const packages = await readPackages(options.packageFilePath);
  const installArgs = ["install", "--global", ...packages];

  if (options.verbose) {
    console.log(`Package file: ${options.packageFilePath}`);
    console.log(`Packages: ${packages.join(", ")}`);
  }

  if (options.dryRun) {
    console.log(formatCommand(options.npmCommand, installArgs));
    return;
  }

  await runCommand(options.npmCommand, installArgs);
}

main().catch((error: unknown) => {
  const message =
    error instanceof Error ? error.message : `Unknown error: ${String(error)}`;
  console.error(`Error: ${message}`);
  console.error("");
  console.error(usage());
  process.exitCode = 1;
});
