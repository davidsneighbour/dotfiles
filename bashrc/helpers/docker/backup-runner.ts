#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { access, constants, mkdir, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join, relative, resolve } from 'node:path';

/**
 * Docker backup orchestrator.
 *
 * Scans a root directory recursively for one of the following files:
 * - backup.toml
 * - backup.sh
 * - backup.ts
 * - backup.js
 * - backup.mjs
 * - backup.cjs
 *
 * Behaviour:
 * - backup.toml: handled by the built-in backup engine
 * - backup.* script: executed directly via the matching runtime
 *
 * This file is designed for Node.js 24+ with native TypeScript execution.
 */

type LogLevel = 'INFO' | 'WARN' | 'ERROR' | 'SUCCESS' | 'DEBUG';
type RunnerMode = 'compose-copy' | 'command';
type ScriptType = 'bash' | 'node';

interface CliOptions {
  root: string;
  destination: string;
  verbose: boolean;
  dryRun: boolean;
  continueOnError: boolean;
  help: boolean;
  afterEachCommand?: string;
  afterAllCommand?: string;
}

interface TaskResult {
  name: string;
  folder: string;
  ok: boolean;
  archivePath?: string;
  durationMs: number;
  type: 'toml' | 'script';
  error?: string;
}

interface BackupTomlConfig {
  enabled?: boolean;
  name?: string;
  mode?: RunnerMode;
  service_root?: string;
  compose_file?: string;
  data_paths?: string[];
  command?: string;
  pre_command?: string;
  post_command?: string;
  upload_command?: string;
  stop_timeout_seconds?: number;
  compression?: 'tar.gz';
  ignore_missing_paths?: boolean;
}

const SCRIPT_CANDIDATES = ['backup.toml', 'backup.sh', 'backup.ts', 'backup.js', 'backup.mjs', 'backup.cjs'];
const SKIP_DIRS = new Set(['.git', 'node_modules', '.cache', '.next', 'dist', 'build', '.idea', '.vscode']);

function printHelp(): void {
  const commandName = basename(process.argv[1] ?? 'backup-runner.ts');
  console.log(`Usage: node ${commandName} --root <path> --destination <path> [options]

Options:
  --root <path>               Root directory to scan recursively
  --destination <path>        Directory where backup archives are written
  --after-each-command <cmd>  Command run after every successful archive
  --after-all-command <cmd>   Command run once after all successful backups
  --dry-run                   Show what would happen without executing it
  --verbose                   Print debug output
  --stop-on-error             Stop on the first failed backup
  --help                      Show this help message

Supported task files:
  backup.toml                 Built-in backup engine
  backup.sh                   Executed with bash
  backup.ts|js|mjs|cjs        Executed with node

Environment passed to child scripts:
  BACKUP_NAME
  BACKUP_HOST
  BACKUP_TIMESTAMP
  BACKUP_TASK_DIR
  BACKUP_OUTPUT_DIR
  BACKUP_WORK_DIR
  BACKUP_ARCHIVE_PATH
  BACKUP_VERBOSE
`);
}

function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = {
    root: '.',
    destination: './backups',
    verbose: false,
    dryRun: false,
    continueOnError: true,
    help: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const current = argv[index];

    switch (current) {
      case '--root': {
        const value = argv[index + 1];
        if (!value) {
          throw new Error('Missing value for --root');
        }
        options.root = value;
        index += 1;
        break;
      }
      case '--destination': {
        const value = argv[index + 1];
        if (!value) {
          throw new Error('Missing value for --destination');
        }
        options.destination = value;
        index += 1;
        break;
      }
      case '--after-each-command': {
        const value = argv[index + 1];
        if (!value) {
          throw new Error('Missing value for --after-each-command');
        }
        options.afterEachCommand = value;
        index += 1;
        break;
      }
      case '--after-all-command': {
        const value = argv[index + 1];
        if (!value) {
          throw new Error('Missing value for --after-all-command');
        }
        options.afterAllCommand = value;
        index += 1;
        break;
      }
      case '--dry-run':
        options.dryRun = true;
        break;
      case '--verbose':
        options.verbose = true;
        break;
      case '--stop-on-error':
        options.continueOnError = false;
        break;
      case '--help':
        options.help = true;
        break;
      default:
        throw new Error(`Unknown argument: ${current}`);
    }
  }

  return options;
}

function log(level: LogLevel, message: string, verbose = true): void {
  if (!verbose && level === 'DEBUG') {
    return;
  }
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] [${level}] ${message}`);
}

async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await access(targetPath, constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

async function ensureDirectory(targetPath: string): Promise<void> {
  await mkdir(targetPath, { recursive: true });
}

async function isExecutable(targetPath: string): Promise<boolean> {
  try {
    await access(targetPath, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function safeName(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '');
}

function createTimestamp(): string {
  return new Date().toISOString().replace(/[:]/g, '-').replace(/\.\d{3}Z$/, 'Z');
}

function interpolate(template: string, variables: Record<string, string>): string {
  return template.replace(/\$\{([a-zA-Z0-9_]+)\}/g, (_match, name: string) => variables[name] ?? '');
}

async function execCommand(command: string, cwd: string, options: { dryRun: boolean; verbose: boolean; env?: NodeJS.ProcessEnv }): Promise<void> {
  if (options.dryRun) {
    log('INFO', `[dry-run] ${cwd}: ${command}`, options.verbose);
    return;
  }

  await new Promise<void>((resolvePromise, rejectPromise) => {
    const child = spawn('bash', ['-lc', command], {
      cwd,
      env: {
        ...process.env,
        ...options.env,
      },
      stdio: 'inherit',
    });

    child.on('error', (error) => {
      rejectPromise(error);
    });

    child.on('close', (code) => {
      if (code === 0) {
        resolvePromise();
        return;
      }
      rejectPromise(new Error(`Command failed with exit code ${code}: ${command}`));
    });
  });
}

async function findTasks(rootDirectory: string, verbose: boolean): Promise<string[]> {
  const results: string[] = [];

  async function walk(currentDirectory: string): Promise<void> {
    const entries = await readdir(currentDirectory, { withFileTypes: true });
    const entryNames = new Set(entries.map((entry) => entry.name));

    for (const candidate of SCRIPT_CANDIDATES) {
      if (entryNames.has(candidate)) {
        results.push(join(currentDirectory, candidate));
        log('DEBUG', `Found task file: ${join(currentDirectory, candidate)}`, verbose);
        return;
      }
    }

    for (const entry of entries) {
      if (!entry.isDirectory()) {
        continue;
      }
      if (SKIP_DIRS.has(entry.name)) {
        continue;
      }
      await walk(join(currentDirectory, entry.name));
    }
  }

  await walk(rootDirectory);
  return results.sort((left, right) => left.localeCompare(right));
}

function parseTomlValue(rawValue: string): unknown {
  const value = rawValue.trim();

  if (value === 'true') {
    return true;
  }
  if (value === 'false') {
    return false;
  }
  if (/^-?\d+$/.test(value)) {
    return Number.parseInt(value, 10);
  }
  if (/^-?\d+\.\d+$/.test(value)) {
    return Number.parseFloat(value);
  }
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
    return value.slice(1, -1);
  }
  if (value.startsWith('[') && value.endsWith(']')) {
    const inner = value.slice(1, -1).trim();
    if (!inner) {
      return [];
    }
    return inner
      .split(',')
      .map((item) => parseTomlValue(item))
      .filter((item): item is string => typeof item === 'string');
  }

  return value;
}

function setNestedValue(target: Record<string, unknown>, keyPath: string[], value: unknown): void {
  let current: Record<string, unknown> = target;

  for (let index = 0; index < keyPath.length - 1; index += 1) {
    const key = keyPath[index];
    const existing = current[key];
    if (typeof existing !== 'object' || existing === null || Array.isArray(existing)) {
      current[key] = {};
    }
    current = current[key] as Record<string, unknown>;
  }

  const lastKey = keyPath[keyPath.length - 1];
  current[lastKey] = value;
}

function parseToml(content: string): Record<string, unknown> {
  const root: Record<string, unknown> = {};
  let currentPath: string[] = [];

  for (const rawLine of content.split(/\r?\n/u)) {
    const line = rawLine.trim();

    if (!line || line.startsWith('#')) {
      continue;
    }

    if (line.startsWith('[') && line.endsWith(']')) {
      currentPath = line.slice(1, -1).split('.').map((part) => part.trim()).filter(Boolean);
      continue;
    }

    const equalsIndex = line.indexOf('=');
    if (equalsIndex === -1) {
      throw new Error(`Invalid TOML line: ${line}`);
    }

    const key = line.slice(0, equalsIndex).trim();
    const rawValue = line.slice(equalsIndex + 1).trim();
    setNestedValue(root, [...currentPath, key], parseTomlValue(rawValue));
  }

  return root;
}

function toBackupTomlConfig(data: Record<string, unknown>): BackupTomlConfig {
  const config = data as BackupTomlConfig;

  if (config.mode && config.mode !== 'compose-copy' && config.mode !== 'command') {
    throw new Error(`Unsupported mode in backup.toml: ${String(config.mode)}`);
  }

  if (config.compression && config.compression !== 'tar.gz') {
    throw new Error(`Unsupported compression in backup.toml: ${String(config.compression)}`);
  }

  if (config.data_paths && !Array.isArray(config.data_paths)) {
    throw new Error('backup.toml field data_paths must be an array of strings');
  }

  return config;
}

async function detectComposeCommand(): Promise<string> {
  try {
    await execCommand('docker compose version >/dev/null 2>&1', process.cwd(), { dryRun: false, verbose: false });
    return 'docker compose';
  } catch {
    await execCommand('docker-compose version >/dev/null 2>&1', process.cwd(), { dryRun: false, verbose: false });
    return 'docker-compose';
  }
}

async function createTarGzFromPaths(cwd: string, archivePath: string, relativePaths: string[], options: { dryRun: boolean; verbose: boolean }): Promise<void> {
  const quotedArchive = shellQuote(archivePath);
  const quotedItems = relativePaths.map((item) => shellQuote(item)).join(' ');
  const command = `tar -czf ${quotedArchive} ${quotedItems}`;
  await execCommand(command, cwd, options);
}

async function createTarGzFromDirectory(sourceDirectory: string, archivePath: string, options: { dryRun: boolean; verbose: boolean }): Promise<void> {
  const command = `tar -czf ${shellQuote(archivePath)} -C ${shellQuote(sourceDirectory)} .`;
  await execCommand(command, sourceDirectory, options);
}

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", `'"'"'`)}'`;
}

async function executeTomlTask(taskPath: string, options: CliOptions, hostName: string): Promise<TaskResult> {
  const startedAt = Date.now();
  const taskDirectory = dirname(taskPath);
  const configContent = await readFile(taskPath, 'utf8');
  const config = toBackupTomlConfig(parseToml(configContent));
  const name = config.name ?? basename(taskDirectory);
  const timestamp = createTimestamp();
  const outputDirectory = join(resolve(options.destination), safeName(hostName));
  const archiveName = `${safeName(name)}-${timestamp}.tar.gz`;
  const archivePath = join(outputDirectory, archiveName);
  const serviceRoot = resolve(taskDirectory, config.service_root ?? '.');
  const variables = {
    archive: archivePath,
    folder: taskDirectory,
    host: hostName,
    name,
    output_dir: outputDirectory,
    timestamp,
  };

  try {
    if (config.enabled === false) {
      log('INFO', `Skipping disabled task: ${taskPath}`, options.verbose);
      return {
        name,
        folder: taskDirectory,
        ok: true,
        durationMs: Date.now() - startedAt,
        type: 'toml',
      };
    }

    await ensureDirectory(outputDirectory);

    if (config.pre_command) {
      await execCommand(interpolate(config.pre_command, variables), serviceRoot, options);
    }

    if ((config.mode ?? 'compose-copy') === 'compose-copy') {
      const composeCommand = await detectComposeCommand();
      const composeFile = resolve(serviceRoot, config.compose_file ?? 'docker-compose.yml');
      const dataPaths = config.data_paths ?? ['data'];
      const relativePaths: string[] = [];

      for (const configuredPath of dataPaths) {
        const absolutePath = resolve(serviceRoot, configuredPath);
        const exists = await pathExists(absolutePath);
        if (!exists) {
          if (config.ignore_missing_paths) {
            log('WARN', `Skipping missing path for ${name}: ${absolutePath}`, options.verbose);
            continue;
          }
          throw new Error(`Configured data path does not exist: ${absolutePath}`);
        }
        relativePaths.push(relative(serviceRoot, absolutePath));
      }

      if (relativePaths.length === 0) {
        throw new Error(`No data paths left to archive for ${name}`);
      }

      const stopTimeout = config.stop_timeout_seconds ?? 30;
      await execCommand(`${composeCommand} -f ${shellQuote(composeFile)} down --timeout ${stopTimeout}`, serviceRoot, options);

      try {
        await createTarGzFromPaths(serviceRoot, archivePath, relativePaths, options);
      } finally {
        await execCommand(`${composeCommand} -f ${shellQuote(composeFile)} up -d`, serviceRoot, options);
      }
    } else {
      if (!config.command) {
        throw new Error(`backup.toml in ${taskDirectory} uses mode=command but command is missing`);
      }
      await execCommand(interpolate(config.command, variables), serviceRoot, options);
    }

    if (config.post_command) {
      await execCommand(interpolate(config.post_command, variables), serviceRoot, options);
    }

    if (config.upload_command) {
      await execCommand(interpolate(config.upload_command, variables), serviceRoot, options);
    }

    return {
      name,
      folder: taskDirectory,
      ok: true,
      archivePath,
      durationMs: Date.now() - startedAt,
      type: 'toml',
    };
  } catch (error) {
    return {
      name,
      folder: taskDirectory,
      ok: false,
      durationMs: Date.now() - startedAt,
      type: 'toml',
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

function detectScriptType(taskPath: string): ScriptType {
  if (taskPath.endsWith('.sh')) {
    return 'bash';
  }
  return 'node';
}

async function executeScriptTask(taskPath: string, options: CliOptions, hostName: string): Promise<TaskResult> {
  const startedAt = Date.now();
  const taskDirectory = dirname(taskPath);
  const name = basename(taskDirectory);
  const timestamp = createTimestamp();
  const outputDirectory = join(resolve(options.destination), safeName(hostName));
  const archiveName = `${safeName(name)}-${timestamp}.tar.gz`;
  const archivePath = join(outputDirectory, archiveName);
  const unique = createHash('sha1').update(`${taskPath}:${timestamp}`).digest('hex').slice(0, 12);
  const workDirectory = join(tmpdir(), `backup-runner-${safeName(name)}-${unique}`);

  try {
    await ensureDirectory(outputDirectory);
    await ensureDirectory(workDirectory);

    if (taskPath.endsWith('.sh')) {
      const executable = await isExecutable(taskPath);
      if (!executable && !options.dryRun) {
        throw new Error(`Script is not executable: ${taskPath}`);
      }
    }

    const env: NodeJS.ProcessEnv = {
      ...process.env,
      BACKUP_NAME: name,
      BACKUP_HOST: hostName,
      BACKUP_TIMESTAMP: timestamp,
      BACKUP_TASK_DIR: taskDirectory,
      BACKUP_OUTPUT_DIR: outputDirectory,
      BACKUP_WORK_DIR: workDirectory,
      BACKUP_ARCHIVE_PATH: archivePath,
      BACKUP_VERBOSE: options.verbose ? '1' : '0',
    };

    const scriptType = detectScriptType(taskPath);
    const command = scriptType === 'bash' ? `${shellQuote(taskPath)}` : `node ${shellQuote(taskPath)}`;
    await execCommand(command, taskDirectory, { ...options, env });

    const archiveAlreadyCreated = await pathExists(archivePath);
    if (!archiveAlreadyCreated) {
      await createTarGzFromDirectory(workDirectory, archivePath, options);
    }

    return {
      name,
      folder: taskDirectory,
      ok: true,
      archivePath,
      durationMs: Date.now() - startedAt,
      type: 'script',
    };
  } catch (error) {
    return {
      name,
      folder: taskDirectory,
      ok: false,
      durationMs: Date.now() - startedAt,
      type: 'script',
      error: error instanceof Error ? error.message : String(error),
    };
  } finally {
    if (!options.dryRun) {
      await rm(workDirectory, { recursive: true, force: true });
    }
  }
}

async function runAfterCommand(commandTemplate: string, result: TaskResult, options: CliOptions, hostName: string): Promise<void> {
  if (!result.archivePath) {
    return;
  }

  const variables = {
    archive: result.archivePath,
    folder: result.folder,
    host: hostName,
    name: result.name,
    output_dir: resolve(options.destination),
    timestamp: createTimestamp(),
  };

  await execCommand(interpolate(commandTemplate, variables), result.folder, options);
}

async function getHostName(): Promise<string> {
  try {
    const content = await readFile('/etc/hostname', 'utf8');
    return content.trim() || 'unknown-host';
  } catch {
    return process.env.HOSTNAME || 'unknown-host';
  }
}

async function validateRootDirectory(rootDirectory: string): Promise<void> {
  const details = await stat(rootDirectory);
  if (!details.isDirectory()) {
    throw new Error(`Root path is not a directory: ${rootDirectory}`);
  }
}

function printSummary(results: TaskResult[]): void {
  const successCount = results.filter((result) => result.ok).length;
  const failureCount = results.length - successCount;

  console.log('');
  console.log('Backup summary');
  console.log(`  Total tasks:   ${results.length}`);
  console.log(`  Successful:    ${successCount}`);
  console.log(`  Failed:        ${failureCount}`);

  for (const result of results) {
    const state = result.ok ? 'OK' : 'FAIL';
    const archive = result.archivePath ? ` -> ${result.archivePath}` : '';
    const error = result.error ? ` (${result.error})` : '';
    console.log(`  [${state}] ${result.name} [${result.type}]${archive}${error}`);
  }
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    printHelp();
    return;
  }

  const rootDirectory = resolve(options.root);
  const destinationDirectory = resolve(options.destination);
  const hostName = safeName(await getHostName());

  await validateRootDirectory(rootDirectory);
  await ensureDirectory(destinationDirectory);

  log('INFO', `Scanning ${rootDirectory} for backup tasks`, options.verbose);
  const tasks = await findTasks(rootDirectory, options.verbose);

  if (tasks.length === 0) {
    log('WARN', 'No backup tasks found.', options.verbose);
    return;
  }

  const results: TaskResult[] = [];

  for (const taskPath of tasks) {
    log('INFO', `Running backup task: ${taskPath}`, options.verbose);

    const result = taskPath.endsWith('.toml')
      ? await executeTomlTask(taskPath, options, hostName)
      : await executeScriptTask(taskPath, options, hostName);

    results.push(result);

    if (result.ok) {
      log('SUCCESS', `Completed ${result.name} in ${result.durationMs} ms`, options.verbose);
      if (options.afterEachCommand) {
        await runAfterCommand(options.afterEachCommand, result, options, hostName);
      }
    } else {
      log('ERROR', `Failed ${result.name}: ${result.error ?? 'unknown error'}`, options.verbose);
      if (!options.continueOnError) {
        break;
      }
    }
  }

  const successfulResults = results.filter((result) => result.ok);
  if (options.afterAllCommand && successfulResults.length > 0) {
    const archiveListPath = join(resolve(options.destination), `${hostName}-archives-${createTimestamp()}.txt`);
    const archiveList = successfulResults
      .map((result) => result.archivePath)
      .filter((value): value is string => typeof value === 'string')
      .join('\n');

    if (!options.dryRun) {
      await ensureDirectory(dirname(archiveListPath));
      await writeFile(archiveListPath, `${archiveList}\n`, 'utf8');
    }

    const variables = {
      archive: archiveListPath,
      folder: resolve(options.destination),
      host: hostName,
      name: 'all-backups',
      output_dir: resolve(options.destination),
      timestamp: createTimestamp(),
    };

    await execCommand(interpolate(options.afterAllCommand, variables), resolve(options.destination), options);
  }

  printSummary(results);

  const failedCount = results.filter((result) => !result.ok).length;
  if (failedCount > 0) {
    process.exitCode = 1;
  }
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  log('ERROR', message, true);
  process.exitCode = 1;
});
