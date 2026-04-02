#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { constants as fsConstants } from 'node:fs';
import {
  access,
  appendFile,
  copyFile,
  mkdir,
  mkdtemp,
  readdir,
  readFile,
  rename,
  rm,
  stat,
  writeFile,
} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';
import { parse as parseToml } from 'smol-toml';

type CleanupAction = 'delete' | 'compress';

interface CleanupPolicy {
  action: CleanupAction;
  keep_hours: number;
}

interface CleanupRule {
  folderslug: string;
  action: CleanupAction;
  keep_hours: number;
}

interface CleanupConfig {
  default: CleanupPolicy;
  rule?: CleanupRule[];
}

interface CliOptions {
  configPath: string;
  logRoot: string;
  tempRoot: string;
  verbose: boolean;
  dryRun: boolean;
  help: boolean;
}

interface CandidateFile {
  absolutePath: string;
  relativePath: string;
  folderSlug: string;
  basename: string;
  size: number;
  mtimeMs: number;
  archiveDay: string;
}

interface RunStats {
  deleted: number;
  compressed: number;
  skipped: number;
  archivesUpdated: number;
}

const SCRIPT_NAME = path.basename(process.argv[1] ?? 'cleanup-logs.ts');
const DEFAULT_CONFIG_PATH = path.join(
  os.homedir(),
  '.config',
  'log-cleanup',
  'config.toml',
);
const DEFAULT_LOG_ROOT = path.join(os.homedir(), '.logs');
const DEFAULT_TEMP_ROOT = path.join(os.homedir(), '.temp', 'logcleanup');
const HOUR_IN_MS = 60 * 60 * 1000;

function printHelp(): void {
  console.log(`
Usage:
  ${SCRIPT_NAME} [--config <path>] [--log-root <path>] [--temp-root <path>] [--verbose] [--dry-run] [--help]

Options:
  --config <path>    Path to TOML configuration file.
                     Default: ${DEFAULT_CONFIG_PATH}
  --log-root <path>  Root log directory.
                     Default: ${DEFAULT_LOG_ROOT}
  --temp-root <path> Temporary working directory.
                     Default: ${DEFAULT_TEMP_ROOT}
  --verbose          Enable verbose output.
                     Also enabled if DNB_VERBOSE=1|true|yes|on
  --dry-run          Show what would happen without changing files.
  --help             Show this help.

Config format:
  [default]
  action = "compress"
  keep_hours = 48

  [[rule]]
  folderslug = "desktop"
  action = "compress"
  keep_hours = 24

  [[rule]]
  folderslug = "services/nginx"
  action = "delete"
  keep_hours = 72
`.trim());
}

function consoleVerbose(message: string, verbose: boolean): void {
  if (verbose) {
    console.log(message);
  }
}

function isVerboseEnv(value: string | undefined): boolean {
  if (!value) {
    return false;
  }

  return ['1', 'true', 'yes', 'on'].includes(value.toLowerCase());
}

function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = {
    configPath: DEFAULT_CONFIG_PATH,
    logRoot: DEFAULT_LOG_ROOT,
    tempRoot: DEFAULT_TEMP_ROOT,
    verbose: isVerboseEnv(process.env['DNB_VERBOSE']),
    dryRun: false,
    help: false,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];

    switch (arg) {
      case '--help':
        options.help = true;
        break;

      case '--verbose':
        options.verbose = true;
        break;

      case '--dry-run':
        options.dryRun = true;
        break;

      case '--config': {
        const value = argv[index + 1];
        if (!value) {
          throw new Error('--config requires a value');
        }
        options.configPath = path.resolve(value);
        index += 1;
        break;
      }

      case '--log-root': {
        const value = argv[index + 1];
        if (!value) {
          throw new Error('--log-root requires a value');
        }
        options.logRoot = path.resolve(value);
        index += 1;
        break;
      }

      case '--temp-root': {
        const value = argv[index + 1];
        if (!value) {
          throw new Error('--temp-root requires a value');
        }
        options.tempRoot = path.resolve(value);
        index += 1;
        break;
      }

      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

async function ensureDir(targetPath: string): Promise<void> {
  await mkdir(targetPath, { recursive: true });
}

async function fileExists(filePath: string): Promise<boolean> {
  try {
    await access(filePath, fsConstants.F_OK);
    return true;
  } catch {
    return false;
  }
}

async function runCommand(
  command: string,
  args: string[],
  cwd: string,
): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk: Buffer | string) => {
      stdout += String(chunk);
    });

    child.stderr.on('data', (chunk: Buffer | string) => {
      stderr += String(chunk);
    });

    child.on('error', (error: Error) => {
      reject(error);
    });

    child.on('close', (code: number | null) => {
      if (code !== 0) {
        reject(
          new Error(
            `${command} ${args.join(' ')} failed with exit code ${String(code)}\n${stderr || stdout}`,
          ),
        );
        return;
      }

      resolve(stdout.trim());
    });
  });
}

async function moveFile(sourcePath: string, targetPath: string): Promise<void> {
  try {
    await rename(sourcePath, targetPath);
  } catch (error: unknown) {
    if (
      error &&
      typeof error === 'object' &&
      'code' in error &&
      error.code === 'EXDEV'
    ) {
      await copyFile(sourcePath, targetPath);
      await rm(sourcePath, { force: true });
      return;
    }

    throw error;
  }
}

function isCleanupAction(value: unknown): value is CleanupAction {
  return value === 'delete' || value === 'compress';
}

function validateConfig(rawConfig: unknown): CleanupConfig {
  if (!rawConfig || typeof rawConfig !== 'object') {
    throw new Error('Config must be an object');
  }

  const configObject = rawConfig as Record<string, unknown>;
  const defaultPolicyRaw = configObject['default'];

  if (!defaultPolicyRaw || typeof defaultPolicyRaw !== 'object') {
    throw new Error('Config must contain a [default] table');
  }

  const defaultPolicyObject = defaultPolicyRaw as Record<string, unknown>;
  const defaultAction = defaultPolicyObject['action'];
  const defaultKeepHours = defaultPolicyObject['keep_hours'];

  if (!isCleanupAction(defaultAction)) {
    throw new Error('default.action must be "delete" or "compress"');
  }

  if (
    typeof defaultKeepHours !== 'number' ||
    !Number.isFinite(defaultKeepHours) ||
    defaultKeepHours < 0
  ) {
    throw new Error('default.keep_hours must be a non-negative number');
  }

  const rules: CleanupRule[] = [];

  if (Array.isArray(configObject['rule'])) {
    for (const item of configObject['rule']) {
      if (!item || typeof item !== 'object') {
        throw new Error('Each [[rule]] entry must be an object');
      }

      const ruleObject = item as Record<string, unknown>;
      const folderslug = ruleObject['folderslug'];
      const action = ruleObject['action'];
      const keepHours = ruleObject['keep_hours'];

      if (typeof folderslug !== 'string' || folderslug.trim() === '') {
        throw new Error('rule.folderslug must be a non-empty string');
      }

      if (folderslug.startsWith('/') || folderslug.includes('..')) {
        throw new Error(`Invalid rule.folderslug: ${folderslug}`);
      }

      if (!isCleanupAction(action)) {
        throw new Error(`Invalid action for rule ${folderslug}`);
      }

      if (
        typeof keepHours !== 'number' ||
        !Number.isFinite(keepHours) ||
        keepHours < 0
      ) {
        throw new Error(`Invalid keep_hours for rule ${folderslug}`);
      }

      rules.push({
        folderslug: folderslug.replace(/^\.?\//, '').replace(/\/+$/, ''),
        action,
        keep_hours: keepHours,
      });
    }
  }

  return {
    default: {
      action: defaultAction,
      keep_hours: defaultKeepHours,
    },
    rule: rules,
  };
}

async function loadConfig(configPath: string): Promise<CleanupConfig> {
  const content = await readFile(configPath, 'utf8');
  const parsed = parseToml(content);
  return validateConfig(parsed);
}

function toFolderSlug(relativeDirectory: string): string {
  if (!relativeDirectory || relativeDirectory === '.') {
    return '.';
  }

  return relativeDirectory.split(path.sep).join('/');
}

function resolvePolicy(config: CleanupConfig, folderSlug: string): CleanupPolicy {
  const rules = config.rule ?? [];
  let bestMatch: CleanupRule | null = null;

  for (const rule of rules) {
    if (
      folderSlug === rule.folderslug ||
      folderSlug.startsWith(`${rule.folderslug}/`)
    ) {
      if (!bestMatch || rule.folderslug.length > bestMatch.folderslug.length) {
        bestMatch = rule;
      }
    }
  }

  if (bestMatch) {
    return {
      action: bestMatch.action,
      keep_hours: bestMatch.keep_hours,
    };
  }

  return config.default;
}

function deriveArchiveDay(filename: string, mtimeMs: number): string {
  const match = filename.match(/(\d{8})/);
  if (match?.[1]) {
    return match[1];
  }

  const date = new Date(mtimeMs);
  const year = String(date.getFullYear());
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');

  return `${year}${month}${day}`;
}

async function findLogCandidates(
  logRoot: string,
  activeTaskLog: string,
): Promise<CandidateFile[]> {
  const result: CandidateFile[] = [];

  async function walk(currentDirectory: string, depth: number): Promise<void> {
    if (depth > 2) {
      return;
    }

    const entries = await readdir(currentDirectory, { withFileTypes: true });

    for (const entry of entries) {
      const absolutePath = path.join(currentDirectory, entry.name);

      if (entry.isDirectory()) {
        await walk(absolutePath, depth + 1);
        continue;
      }

      if (!entry.isFile()) {
        continue;
      }

      if (!entry.name.endsWith('.log')) {
        continue;
      }

      if (absolutePath === activeTaskLog) {
        continue;
      }

      const fileStat = await stat(absolutePath);
      const relativePath = path.relative(logRoot, absolutePath);
      const folderRelative = path.dirname(relativePath);
      const folderSlug = toFolderSlug(folderRelative);

      result.push({
        absolutePath,
        relativePath,
        folderSlug,
        basename: path.basename(absolutePath),
        size: fileStat.size,
        mtimeMs: fileStat.mtimeMs,
        archiveDay: deriveArchiveDay(entry.name, fileStat.mtimeMs),
      });
    }
  }

  await walk(logRoot, 0);
  return result;
}

async function writeTaskLog(
  message: string,
  verbose: boolean,
  taskLogPath: string,
  level: 'INFO' | 'WARN' | 'ERROR' = 'INFO',
): Promise<void> {
  const line = `[${new Date().toISOString()}] [${level}] ${message}\n`;
  await appendFile(taskLogPath, line, 'utf8');

  if (verbose || level !== 'INFO') {
    const stream = level === 'ERROR' ? process.stderr : process.stdout;
    stream.write(line);
  }
}

async function acquireLock(lockPath: string): Promise<void> {
  try {
    await writeFile(lockPath, String(process.pid), { flag: 'wx' });
  } catch (error: unknown) {
    if (
      error &&
      typeof error === 'object' &&
      'code' in error &&
      error.code === 'EEXIST'
    ) {
      throw new Error(
        `Another cleanup run appears to be active. Lock file exists: ${lockPath}`,
      );
    }

    throw error;
  }
}

async function releaseLock(lockPath: string): Promise<void> {
  if (await fileExists(lockPath)) {
    await rm(lockPath, { force: true });
  }
}

function groupCandidatesForCompression(
  files: CandidateFile[],
): Map<string, CandidateFile[]> {
  const groups = new Map<string, CandidateFile[]>();

  for (const file of files) {
    const key = `${path.dirname(file.absolutePath)}::${file.archiveDay}`;
    const existing = groups.get(key);

    if (existing) {
      existing.push(file);
    } else {
      groups.set(key, [file]);
    }
  }

  return groups;
}

function archivePathFor(directoryPath: string, archiveDay: string): string {
  return path.join(directoryPath, `${archiveDay}.logs.tar.xz`);
}

async function ensureUniquePath(
  baseDir: string,
  desiredName: string,
): Promise<string> {
  const originalBase = path.basename(desiredName, path.extname(desiredName));
  const extension = path.extname(desiredName);

  let candidate = desiredName;
  let counter = 1;

  while (await fileExists(path.join(baseDir, candidate))) {
    candidate = `${originalBase}.${counter}${extension}`;
    counter += 1;
  }

  return candidate;
}

async function deleteFiles(
  files: CandidateFile[],
  taskLogPath: string,
  verbose: boolean,
  dryRun: boolean,
  stats: RunStats,
): Promise<void> {
  for (const file of files) {
    await writeTaskLog(
      `${dryRun ? 'Would delete' : 'Deleting'} ${file.absolutePath}`,
      verbose,
      taskLogPath,
    );

    if (!dryRun) {
      await rm(file.absolutePath, { force: true });
    }

    stats.deleted += 1;
  }
}

async function compressGroup(
  files: CandidateFile[],
  tempRoot: string,
  taskLogPath: string,
  verbose: boolean,
  dryRun: boolean,
  stats: RunStats,
): Promise<void> {
  if (files.length === 0) {
    return;
  }

  const targetDirectory = path.dirname(files[0].absolutePath);
  const archiveDay = files[0].archiveDay;
  const archivePath = archivePathFor(targetDirectory, archiveDay);

  await ensureDir(tempRoot);
  const temporaryRoot = await mkdtemp(path.join(tempRoot, 'cleanup-logs-'));
  const payloadDir = path.join(temporaryRoot, 'payload');

  try {
    await ensureDir(payloadDir);

    if (await fileExists(archivePath)) {
      await writeTaskLog(
        `Rebuilding existing archive ${archivePath}`,
        verbose,
        taskLogPath,
      );

      if (!dryRun) {
        await runCommand(
          'tar',
          ['-xJf', archivePath, '-C', payloadDir],
          temporaryRoot,
        );
      }
    } else {
      await writeTaskLog(
        `Creating new archive ${archivePath}`,
        verbose,
        taskLogPath,
      );
    }

    for (const file of files) {
      const destinationName = await ensureUniquePath(payloadDir, file.basename);
      const destinationPath = path.join(payloadDir, destinationName);

      if (destinationName !== file.basename) {
        await writeTaskLog(
          `Filename collision for ${file.absolutePath}; storing in archive as ${destinationName}`,
          verbose,
          taskLogPath,
          'WARN',
        );
      }

      if (!dryRun) {
        await copyFile(file.absolutePath, destinationPath);
      }
    }

    if (!dryRun) {
      const temporaryArchive = path.join(temporaryRoot, 'archive.tar.xz');

      await runCommand(
        'tar',
        [
          '--sort=name',
          '--mtime=@0',
          '--owner=0',
          '--group=0',
          '--numeric-owner',
          '-cJf',
          temporaryArchive,
          '-C',
          payloadDir,
          '.',
        ],
        temporaryRoot,
      );

      await moveFile(temporaryArchive, archivePath);

      for (const file of files) {
        await rm(file.absolutePath, { force: true });
      }
    }

    stats.compressed += files.length;
    stats.archivesUpdated += 1;

    await writeTaskLog(
      `${dryRun ? 'Would compress' : 'Compressed'} ${files.length} file(s) into ${archivePath}`,
      verbose,
      taskLogPath,
    );
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
}

function formatCurrentDay(date: Date): string {
  return [
    String(date.getFullYear()),
    String(date.getMonth() + 1).padStart(2, '0'),
    String(date.getDate()).padStart(2, '0'),
  ].join('');
}

async function ensureBinaryAvailable(binary: string): Promise<void> {
  try {
    await runCommand(binary, ['--version'], process.cwd());
  } catch (error: unknown) {
    const message =
      error instanceof Error ? error.message : `Unknown error: ${String(error)}`;
    throw new Error(`Required external tool not available: ${binary}. ${message}`);
  }
}

async function main(options: CliOptions): Promise<void> {
  if (options.help) {
    printHelp();
    return;
  }

  consoleVerbose(`[startup] logRoot=${options.logRoot}`, options.verbose);
  consoleVerbose(`[startup] configPath=${options.configPath}`, options.verbose);
  consoleVerbose(`[startup] tempRoot=${options.tempRoot}`, options.verbose);
  consoleVerbose(`[startup] dryRun=${String(options.dryRun)}`, options.verbose);
  consoleVerbose(`[startup] verbose=${String(options.verbose)}`, options.verbose);

  await ensureDir(options.logRoot);
  await ensureDir(options.tempRoot);

  const currentDay = formatCurrentDay(new Date());
  const taskLogPath = path.join(options.logRoot, `cleanup-${currentDay}.log`);
  const lockPath = path.join(options.logRoot, '.cleanup-logs.lock');

  consoleVerbose(`[startup] taskLogPath=${taskLogPath}`, options.verbose);
  consoleVerbose(`[startup] lockPath=${lockPath}`, options.verbose);

  await acquireLock(lockPath);

  const stats: RunStats = {
    deleted: 0,
    compressed: 0,
    skipped: 0,
    archivesUpdated: 0,
  };

  try {
    await writeTaskLog('Starting cleanup run', options.verbose, taskLogPath);

    await access(options.configPath, fsConstants.R_OK);
    const config = await loadConfig(options.configPath);

    if (options.verbose) {
      console.log('[config] Loaded cleanup config successfully');
      console.log(
        `[config] default action=${config.default.action}, keep_hours=${String(config.default.keep_hours)}`,
      );

      for (const rule of config.rule ?? []) {
        console.log(
          `[config] rule folderslug=${rule.folderslug}, action=${rule.action}, keep_hours=${String(rule.keep_hours)}`,
        );
      }
    }

    await ensureBinaryAvailable('tar');
    await ensureBinaryAvailable('xz');

    const allCandidates = await findLogCandidates(options.logRoot, taskLogPath);
    const now = Date.now();

    await writeTaskLog(
      `Found ${String(allCandidates.length)} candidate log file(s) under ${options.logRoot}`,
      true,
      taskLogPath,
    );

    if (options.verbose) {
      if (allCandidates.length === 0) {
        console.log('[scan] No .log files found.');
      } else {
        console.log('[scan] Candidate files:');
        for (const file of allCandidates) {
          console.log(
            `  - ${file.relativePath} | folder=${file.folderSlug} | archiveDay=${file.archiveDay}`,
          );
        }
      }
    }

    const deleteQueue: CandidateFile[] = [];
    const compressQueue: CandidateFile[] = [];

    for (const file of allCandidates) {
      const policy = resolvePolicy(config, file.folderSlug);
      const ageMs = now - file.mtimeMs;
      const keepMs = policy.keep_hours * HOUR_IN_MS;
      const ageHours = ageMs / HOUR_IN_MS;

      if (ageMs < keepMs) {
        stats.skipped += 1;

        if (options.verbose) {
          console.log(
            `[skip] ${file.relativePath} | age=${ageHours.toFixed(2)}h | keep=${String(policy.keep_hours)}h | action=${policy.action}`,
          );
        }

        continue;
      }

      if (policy.action === 'delete') {
        deleteQueue.push(file);

        if (options.verbose) {
          console.log(
            `[queue:delete] ${file.relativePath} | age=${ageHours.toFixed(2)}h | keep=${String(policy.keep_hours)}h`,
          );
        }
      } else {
        compressQueue.push(file);

        if (options.verbose) {
          console.log(
            `[queue:compress] ${file.relativePath} | age=${ageHours.toFixed(2)}h | keep=${String(policy.keep_hours)}h | archiveDay=${file.archiveDay}`,
          );
        }
      }
    }

    await writeTaskLog(
      `Decision summary: delete=${String(deleteQueue.length)}, compress=${String(compressQueue.length)}, skipped=${String(stats.skipped)}`,
      true,
      taskLogPath,
    );

    await deleteFiles(
      deleteQueue,
      taskLogPath,
      options.verbose,
      options.dryRun,
      stats,
    );

    const compressionGroups = groupCandidatesForCompression(compressQueue);
    for (const groupFiles of compressionGroups.values()) {
      await compressGroup(
        groupFiles,
        options.tempRoot,
        taskLogPath,
        options.verbose,
        options.dryRun,
        stats,
      );
    }

    await writeTaskLog(
      `Finished cleanup run: deleted=${String(stats.deleted)}, compressed=${String(stats.compressed)}, archivesUpdated=${String(stats.archivesUpdated)}, skipped=${String(stats.skipped)}`,
      options.verbose,
      taskLogPath,
    );
  } finally {
    await releaseLock(lockPath);
  }
}

const entryScript = process.argv[1];
const isDirectRun =
  typeof entryScript === 'string' &&
  import.meta.url === pathToFileURL(path.resolve(entryScript)).href;

if (isDirectRun) {
  const options = parseArgs(process.argv);

  main(options).catch(async (error: unknown) => {
    const currentDay = formatCurrentDay(new Date());
    const fallbackLogPath = path.join(
      DEFAULT_LOG_ROOT,
      `cleanup-${currentDay}.log`,
    );

    try {
      await ensureDir(DEFAULT_LOG_ROOT);

      const message =
        error instanceof Error
          ? (error.stack ?? error.message)
          : `Unknown error: ${String(error)}`;

      await writeTaskLog(message, true, fallbackLogPath, 'ERROR');
    } catch (loggingError: unknown) {
      console.error('Failed to write fallback log:', loggingError);
      console.error(error);
    }

    process.exitCode = 1;
  });
}
