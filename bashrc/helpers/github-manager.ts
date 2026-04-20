#!/usr/bin/env -S node

/**
 * GitHub repository manager.
 *
 * Features:
 * - Inventory local repositories in a base directory
 * - Pull updates from each local repository's upstream/default remote
 * - Show local changes only when changes exist
 * - Audit repositories for sync state, conflict state, dirty state, and remote commits by others
 * - Fetch GitHub repositories for an owner via `gh`
 * - Retrieve repository metadata and tags
 * - Clone repositories filtered by topic
 *
 * Behaviour:
 * - Global startup failures stop the run
 * - Per-repository failures are reported and the run continues
 *
 * Requirements:
 * - Node.js 22+
 * - git
 * - gh (GitHub CLI), authenticated via `gh auth login`
 *
 * Examples:
 *   node github-manager.ts --help
 *   node github-manager.ts inventory
 *   node github-manager.ts pull --base-path ~/github.com/davidsneighbour
 *   node github-manager.ts status
 *   node github-manager.ts audit --author-email hello@example.com
 *   node github-manager.ts remote-list --owner davidsneighbour
 *   node github-manager.ts clone-by-topic --owner davidsneighbour --topic hugo
 *   node github-manager.ts sync-all --owner davidsneighbour --topic astro
 */

import { type SpawnSyncReturns, spawnSync } from 'node:child_process';
import { existsSync, readdirSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { ensureNodeVersion } from './_lib/node.ts';

ensureNodeVersion(25);

type LogLevel = 'info' | 'warn' | 'error' | 'debug';

type CommandName =
  | 'help'
  | 'inventory'
  | 'pull'
  | 'status'
  | 'audit'
  | 'audit-manual'
  | 'remote-list'
  | 'clone-by-topic'
  | 'sync-all';

interface CliConfig {
  basePath: string;
  owner: string;
  topicFilters: string[];
  includeArchived: boolean;
  includeForks: boolean;
  dryRun: boolean;
  verbose: boolean;
  command: CommandName;
  allowedAuthorEmails: string[];
}

interface CommandContext {
  config: CliConfig;
}

interface CommandDefinition {
  name: CommandName;
  description: string;
  run: (context: CommandContext) => Promise<void>;
}

interface ExecCommandOptions {
  cwd?: string;
  allowFailure?: boolean;
  silent?: boolean;
}

interface ExecResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

interface LocalRepository {
  name: string;
  absolutePath: string;
  hasGitDirectory: boolean;
  currentBranch: string | null;
  upstreamRef: string | null;
  defaultRemoteName: string | null;
}

interface GhNode {
  name: string;
}

interface GhLatestRelease {
  name: string | null;
  tagName: string | null;
  isDraft?: boolean;
  isPrerelease?: boolean;
  publishedAt?: string | null;
}

interface GhRepositorySummary {
  name: string;
  nameWithOwner: string;
  description: string | null;
  homepageUrl: string | null;
  isArchived: boolean;
  isFork: boolean;
  url: string;
  pushedAt: string | null;
  visibility: string;
  repositoryTopics?: GhNode[];
  latestRelease?: GhLatestRelease | null;
  licenseInfo?: {
    key?: string | null;
    name?: string | null;
    spdxId?: string | null;
  } | null;
  defaultBranchRef?: {
    name?: string | null;
  } | null;
}

interface GhRepositoryTag {
  name: string;
  commit: {
    sha: string;
    url: string;
  };
  zipball_url: string;
  tarball_url: string;
  node_id?: string;
}

interface RepositoryInventoryRecord {
  repo: GhRepositorySummary;
  tags: GhRepositoryTag[];
}

interface RemoteOnlyCommit {
  hash: string;
  authorName: string;
  authorEmail: string;
  isOurs: boolean;
}

interface RepositoryAuditResult {
  name: string;
  absolutePath: string;
  upstreamRef: string | null;
  dirty: boolean;
  dirtyFiles: string[];
  conflicted: boolean;
  conflictFiles: string[];
  mergeInProgress: boolean;
  rebaseInProgress: boolean;
  cherryPickInProgress: boolean;
  revertInProgress: boolean;
  aheadCount: number;
  behindCount: number;
  inSync: boolean;
  diverged: boolean;
  stateOk: boolean;
  remoteOnlyCommits: RemoteOnlyCommit[];
  hasRemoteCommitsByOthers: boolean;
  broken: boolean;
  brokenReason: string | null;
}

interface RepoOperationResult<T> {
  ok: boolean;
  value?: T;
  errorMessage?: string;
}

const DEFAULT_BASE_PATH = '~/github.com/davidsneighbour';
const DEFAULT_OWNER = 'davidsneighbour';
const DEFAULT_ALLOWED_AUTHOR_EMAILS: string[] = [];

const commandRegistry: Record<CommandName, CommandDefinition> = {
  help: {
    name: 'help',
    description: 'Show help output.',
    run: async () => {
      printHelp();
    },
  },
  inventory: {
    name: 'inventory',
    description: 'List local repositories in the base path.',
    run: async ({ config }) => {
      const repos = inventoryLocalRepositories(config.basePath, config.verbose);

      if (repos.length === 0) {
        log('warn', `No repositories found in "${config.basePath}".`);
        return;
      }

      for (const repo of repos) {
        console.log(
          [
            repo.name,
            `path=${repo.absolutePath}`,
            `branch=${repo.currentBranch ?? 'unknown'}`,
            `upstream=${repo.upstreamRef ?? 'none'}`,
            `remote=${repo.defaultRemoteName ?? 'none'}`,
          ].join(' | '),
        );
      }
    },
  },
  pull: {
    name: 'pull',
    description:
      'Pull updates for each local repository using its upstream/default remote.',
    run: async ({ config }) => {
      const repos = inventoryLocalRepositories(config.basePath, config.verbose);

      if (repos.length === 0) {
        log('warn', `No repositories found in "${config.basePath}".`);
        return;
      }

      for (const repo of repos) {
        await runRepoOperationAsync(repo.name, 'pull', async () => {
          await pullRepository(repo, config);
        });
      }
    },
  },
  status: {
    name: 'status',
    description: 'Show git changes for local repositories, silent when clean.',
    run: async ({ config }) => {
      const repos = inventoryLocalRepositories(config.basePath, config.verbose);

      if (repos.length === 0) {
        log('warn', `No repositories found in "${config.basePath}".`);
        return;
      }

      for (const repo of repos) {
        runRepoOperation(repo.name, 'status', () => {
          showRepositoryChanges(repo, config.verbose);
        });
      }
    },
  },
  audit: {
    name: 'audit',
    description: 'Check state, sync, conflicts, and remote commits by others.',
    run: async ({ config }) => {
      const repos = inventoryLocalRepositories(config.basePath, config.verbose);

      if (repos.length === 0) {
        log('warn', `No repositories found in "${config.basePath}".`);
        return;
      }

      for (const repo of repos) {
        const result = runRepoOperation(repo.name, 'audit', () => {
          return auditRepository(repo, config);
        });

        if (!result.ok || !result.value) {
          printBrokenAuditResult(repo, result.errorMessage ?? 'Unknown error');
          continue;
        }

        printAuditResult(result.value, config.verbose);
      }
    },
  },
  'audit-manual': {
    name: 'audit-manual',
    description:
      'Run audit and print only repositories that need manual intervention.',
    run: async ({ config }) => {
      const repos = inventoryLocalRepositories(config.basePath, config.verbose);

      if (repos.length === 0) {
        log('warn', `No repositories found in "${config.basePath}".`);
        return;
      }

      for (const repo of repos) {
        const result = runRepoOperation(repo.name, 'audit-manual', () => {
          return auditRepository(repo, config);
        });

        if (!result.ok || !result.value) {
          console.log(repo.name);
          continue;
        }

        if (requiresManualIntervention(result.value)) {
          console.log(result.value.name);
        }
      }
    },
  },
  'remote-list': {
    name: 'remote-list',
    description:
      'List remote GitHub repositories for an owner and fetch metadata plus tags.',
    run: async ({ config }) => {
      const records = await fetchRemoteRepositoryInventory(config);

      for (const record of records) {
        const topics = (record.repo.repositoryTopics ?? [])
          .map((topic) => topic.name)
          .join(', ');
        const tagNames = record.tags.map((tag) => tag.name).join(', ');

        console.log(`${record.repo.nameWithOwner}`);
        console.log(`  description: ${record.repo.description ?? ''}`);
        console.log(`  homepage: ${record.repo.homepageUrl ?? ''}`);
        console.log(`  visibility: ${record.repo.visibility}`);
        console.log(`  archived: ${String(record.repo.isArchived)}`);
        console.log(`  fork: ${String(record.repo.isFork)}`);
        console.log(
          `  default-branch: ${record.repo.defaultBranchRef?.name ?? ''}`,
        );
        console.log(
          `  latest-release: ${record.repo.latestRelease?.tagName ?? record.repo.latestRelease?.name ?? ''}`,
        );
        console.log(`  topics: ${topics}`);
        console.log(`  tags: ${tagNames}`);
        console.log('');
      }
    },
  },
  'clone-by-topic': {
    name: 'clone-by-topic',
    description: 'Clone remote repositories filtered by one or more topics.',
    run: async ({ config }) => {
      if (config.topicFilters.length === 0) {
        throw new Error('clone-by-topic requires at least one --topic value.');
      }

      const repositories = await fetchRemoteRepositories(config);
      const filtered = filterRepositoriesByTopics(
        repositories,
        config.topicFilters,
      );

      if (filtered.length === 0) {
        log(
          'warn',
          `No repositories matched topics: ${config.topicFilters.join(', ')}`,
        );
        return;
      }

      for (const repo of filtered) {
        await runRepoOperationAsync(repo.nameWithOwner, 'clone', async () => {
          await cloneRepositoryIfMissing(repo, config);
        });
      }
    },
  },
  'sync-all': {
    name: 'sync-all',
    description:
      'Run pull, status, audit, and optionally clone-by-topic in one pass.',
    run: async ({ config }) => {
      const localRepos = inventoryLocalRepositories(
        config.basePath,
        config.verbose,
      );

      for (const repo of localRepos) {
        await runRepoOperationAsync(repo.name, 'pull', async () => {
          await pullRepository(repo, config);
        });
      }

      for (const repo of localRepos) {
        runRepoOperation(repo.name, 'status', () => {
          showRepositoryChanges(repo, config.verbose);
        });
      }

      for (const repo of localRepos) {
        const result = runRepoOperation(repo.name, 'audit', () => {
          return auditRepository(repo, config);
        });

        if (!result.ok || !result.value) {
          printBrokenAuditResult(repo, result.errorMessage ?? 'Unknown error');
          continue;
        }

        printAuditResult(result.value, config.verbose);
      }

      if (config.topicFilters.length > 0) {
        const repositories = await fetchRemoteRepositories(config);
        const filtered = filterRepositoriesByTopics(
          repositories,
          config.topicFilters,
        );

        for (const repo of filtered) {
          await runRepoOperationAsync(repo.nameWithOwner, 'clone', async () => {
            await cloneRepositoryIfMissing(repo, config);
          });
        }
      }
    },
  },
};

async function main(): Promise<void> {
  const config = parseArgs(process.argv.slice(2));

  if (config.command === 'help') {
    printHelp();
    return;
  }

  ensureCommandAvailable('git');
  ensureCommandAvailable('gh');
  ensureGhAuthenticated();

  const command = commandRegistry[config.command];
  await command.run({ config });
}

function parseArgs(argv: string[]): CliConfig {
  const config: CliConfig = {
    basePath: expandHomeDirectory(DEFAULT_BASE_PATH),
    owner: DEFAULT_OWNER,
    topicFilters: [],
    includeArchived: false,
    includeForks: false,
    dryRun: false,
    verbose: false,
    command: 'help',
    allowedAuthorEmails: [...DEFAULT_ALLOWED_AUTHOR_EMAILS],
  };

  if (argv.length === 0) {
    printHelp();
    process.exit(0);
  }

  const [commandToken, ...rest] = argv;

  if (!commandToken || !isCommandName(commandToken)) {
    throw new Error(
      `Unknown command "${commandToken ?? ''}". Run with --help.`,
    );
  }

  config.command = commandToken;

  for (let index = 0; index < rest.length; index += 1) {
    const token = rest[index];

    switch (token) {
      case '--base-path': {
        const value = rest[index + 1];
        if (!value) {
          throw new Error('--base-path requires a value.');
        }
        config.basePath = expandHomeDirectory(value);
        index += 1;
        break;
      }

      case '--owner': {
        const value = rest[index + 1];
        if (!value) {
          throw new Error('--owner requires a value.');
        }
        config.owner = value;
        index += 1;
        break;
      }

      case '--topic': {
        const value = rest[index + 1];
        if (!value) {
          throw new Error('--topic requires a value.');
        }
        config.topicFilters.push(value);
        index += 1;
        break;
      }

      case '--author-email': {
        const value = rest[index + 1];
        if (!value) {
          throw new Error('--author-email requires a value.');
        }
        config.allowedAuthorEmails.push(value.trim().toLowerCase());
        index += 1;
        break;
      }

      case '--include-archived':
        config.includeArchived = true;
        break;

      case '--include-forks':
        config.includeForks = true;
        break;

      case '--dry-run':
        config.dryRun = true;
        break;

      case '--verbose':
        config.verbose = true;
        break;

      case '--help':
        printHelp();
        process.exit(0);

      default:
        throw new Error(`Unknown option "${token}". Run with --help.`);
    }
  }

  return config;
}

function printHelp(): void {
  const commandName = getCommandName();

  console.log(
    `
Usage:
  ${commandName} <command> [options]

Commands:
  inventory         List local repositories in the base path
  pull              Pull updates in all local repositories
  status            Show local changes only when changes exist
  audit             Check state, sync, conflicts, and remote commits by others
  audit-manual      Run audit and print only repositories needing manual intervention
  remote-list       List remote repositories with metadata and tags
  clone-by-topic    Clone remote repositories filtered by topic
  sync-all          Pull, status, audit, and optionally clone-by-topic
  help              Show this help output

Options:
  --base-path <path>      Base directory to scan
                          Default: ${DEFAULT_BASE_PATH}
  --owner <name>          GitHub owner/user to inspect
                          Default: ${DEFAULT_OWNER}
  --topic <topic>         Topic filter, repeatable
  --author-email <email>  Allowed commit author email, repeatable
  --include-archived      Include archived repositories
  --include-forks         Include fork repositories
  --dry-run               Print actions without changing anything
  --verbose               Show additional output
  --help                  Show help output

Examples:
  ${commandName} inventory
  ${commandName} pull --base-path ~/github.com/davidsneighbour
  ${commandName} status --verbose
  ${commandName} audit --author-email patrick@example.com
  ${commandName} audit-manual --author-email patrick@example.com
  ${commandName} remote-list --owner davidsneighbour
  ${commandName} clone-by-topic --owner davidsneighbour --topic hugo --topic astro
  ${commandName} sync-all --topic hugo --author-email hello@example.com
`.trim(),
  );
}

function getCommandName(): string {
  const argv1 = process.argv[1];

  if (!argv1) {
    return 'github-manager';
  }

  const segments = argv1.split('/');
  return segments.at(-1) ?? 'github-manager';
}

function isCommandName(value: string): value is CommandName {
  return value in commandRegistry;
}

function expandHomeDirectory(inputPath: string): string {
  if (inputPath === '~') {
    return homedir();
  }

  if (inputPath.startsWith('~/')) {
    return join(homedir(), inputPath.slice(2));
  }

  return resolve(inputPath);
}

function log(level: LogLevel, message: string): void {
  const prefixMap: Record<LogLevel, string> = {
    info: '[info]',
    warn: '[warn]',
    error: '[error]',
    debug: '[debug]',
  };

  const output = `${prefixMap[level]} ${message}`;

  if (level === 'error') {
    console.error(output);
    return;
  }

  console.log(output);
}

function ensureCommandAvailable(command: string): void {
  const result = spawnSync(command, ['--version'], {
    encoding: 'utf8',
    stdio: 'ignore',
  });

  if (result.error || result.status !== 0) {
    throw new Error(`Required command "${command}" is not available in PATH.`);
  }
}

function ensureGhAuthenticated(): void {
  const result = execCommand('gh', ['auth', 'status'], {
    allowFailure: true,
    silent: true,
  });

  if (result.exitCode !== 0) {
    throw new Error(
      'GitHub CLI is not authenticated. Run "gh auth login" first.',
    );
  }
}

function execCommand(
  command: string,
  args: string[],
  options: ExecCommandOptions = {},
): ExecResult {
  const result: SpawnSyncReturns<string> = spawnSync(command, args, {
    cwd: options.cwd,
    encoding: 'utf8',
  });

  const stdout = result.stdout ?? '';
  const stderr = result.stderr ?? '';
  const exitCode = result.status ?? 1;

  if (exitCode !== 0 && !options.allowFailure) {
    const renderedArgs = [command, ...args].join(' ');
    throw new Error(
      [
        `Command failed: ${renderedArgs}`,
        options.cwd ? `cwd: ${options.cwd}` : '',
        stdout ? `stdout:\n${stdout}` : '',
        stderr ? `stderr:\n${stderr}` : '',
      ]
        .filter(Boolean)
        .join('\n'),
    );
  }

  if (!options.silent && stderr.trim().length > 0) {
    log('debug', stderr.trim());
  }

  return { stdout, stderr, exitCode };
}

function runRepoOperation<T>(
  repoName: string,
  operationName: string,
  operation: () => T,
): RepoOperationResult<T> {
  try {
    return {
      ok: true,
      value: operation(),
    };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[repo-error] ${repoName}: ${operationName} failed`);
    console.error(message);
    console.error('');

    return {
      ok: false,
      errorMessage: message,
    };
  }
}

async function runRepoOperationAsync<T>(
  repoName: string,
  operationName: string,
  operation: () => Promise<T>,
): Promise<RepoOperationResult<T>> {
  try {
    return {
      ok: true,
      value: await operation(),
    };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[repo-error] ${repoName}: ${operationName} failed`);
    console.error(message);
    console.error('');

    return {
      ok: false,
      errorMessage: message,
    };
  }
}

function inventoryLocalRepositories(
  basePath: string,
  verbose: boolean,
): LocalRepository[] {
  if (!existsSync(basePath)) {
    throw new Error(`Base path does not exist: "${basePath}"`);
  }

  const directoryEntries = readdirSync(basePath, { withFileTypes: true });
  const repositories: LocalRepository[] = [];

  for (const entry of directoryEntries) {
    if (!entry.isDirectory()) {
      continue;
    }

    const absolutePath = join(basePath, entry.name);
    const gitDirectory = join(absolutePath, '.git');

    if (!existsSync(gitDirectory)) {
      if (verbose) {
        log('debug', `Skipping non-git directory: ${absolutePath}`);
      }
      continue;
    }

    const result = runRepoOperation(entry.name, 'inventory', () => {
      const upstreamRef = getUpstreamRef(absolutePath);

      return {
        name: entry.name,
        absolutePath,
        hasGitDirectory: true,
        currentBranch: getCurrentBranch(absolutePath),
        upstreamRef,
        defaultRemoteName: getDefaultRemoteName(absolutePath, upstreamRef),
      } satisfies LocalRepository;
    });

    if (!result.ok || !result.value) {
      continue;
    }

    repositories.push(result.value);
  }

  repositories.sort((left, right) => left.name.localeCompare(right.name));
  return repositories;
}

function getCurrentBranch(repoPath: string): string | null {
  const result = execCommand('git', ['rev-parse', '--abbrev-ref', 'HEAD'], {
    cwd: repoPath,
    allowFailure: true,
    silent: true,
  });

  if (result.exitCode !== 0) {
    return null;
  }

  const branch = result.stdout.trim();
  return branch.length > 0 ? branch : null;
}

function getUpstreamRef(repoPath: string): string | null {
  const result = execCommand(
    'git',
    ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}'],
    {
      cwd: repoPath,
      allowFailure: true,
      silent: true,
    },
  );

  if (result.exitCode !== 0) {
    return null;
  }

  const upstreamRef = result.stdout.trim();
  return upstreamRef.length > 0 ? upstreamRef : null;
}

function getDefaultRemoteName(
  repoPath: string,
  upstreamRef: string | null,
): string | null {
  if (upstreamRef && upstreamRef.includes('/')) {
    const [remoteName] = upstreamRef.split('/');
    return remoteName ?? null;
  }

  const remotesResult = execCommand('git', ['remote'], {
    cwd: repoPath,
    allowFailure: true,
    silent: true,
  });

  if (remotesResult.exitCode !== 0) {
    return null;
  }

  const remotes = remotesResult.stdout
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  if (remotes.includes('origin')) {
    return 'origin';
  }

  return remotes[0] ?? null;
}

async function pullRepository(
  repo: LocalRepository,
  config: CliConfig,
): Promise<void> {
  if (!repo.defaultRemoteName) {
    log('warn', `Skipping ${repo.name}: no remote found.`);
    return;
  }

  log('info', `Pulling ${repo.name} from remote "${repo.defaultRemoteName}"`);

  if (config.dryRun) {
    return;
  }

  if (repo.upstreamRef) {
    execCommand('git', ['pull', '--ff-only'], {
      cwd: repo.absolutePath,
      silent: !config.verbose,
    });
    return;
  }

  const branch = repo.currentBranch;
  if (!branch) {
    log(
      'warn',
      `Skipping ${repo.name}: current branch could not be determined.`,
    );
    return;
  }

  execCommand('git', ['pull', '--ff-only', repo.defaultRemoteName, branch], {
    cwd: repo.absolutePath,
    silent: !config.verbose,
  });
}

function showRepositoryChanges(repo: LocalRepository, verbose: boolean): void {
  const result = execCommand('git', ['status', '--short'], {
    cwd: repo.absolutePath,
    allowFailure: true,
    silent: true,
  });

  if (result.exitCode !== 0) {
    log('warn', `Unable to read status for ${repo.name}`);
    return;
  }

  const trimmed = result.stdout.trim();

  if (trimmed.length === 0) {
    if (verbose) {
      log('debug', `No changes in ${repo.name}`);
    }
    return;
  }

  console.log(`${repo.name}`);
  console.log(trimmed);
  console.log('');
}

function fetchRepository(
  repoPath: string,
  verbose: boolean,
  dryRun: boolean,
): void {
  if (dryRun) {
    if (verbose) {
      log('debug', `Dry run: would fetch ${repoPath}`);
    }
    return;
  }

  execCommand('git', ['fetch', '--prune'], {
    cwd: repoPath,
    allowFailure: false,
    silent: !verbose,
  });
}

function getGitMetadataPath(repoPath: string, relativePath: string): string {
  const dotGitPath = join(repoPath, '.git');

  if (existsSync(dotGitPath)) {
    const dotGitStats = statSync(dotGitPath);

    if (dotGitStats.isDirectory()) {
      return join(dotGitPath, relativePath);
    }
  }

  return join(dotGitPath, relativePath);
}

function getConflictFiles(repoPath: string): string[] {
  const result = execCommand(
    'git',
    ['diff', '--name-only', '--diff-filter=U'],
    {
      cwd: repoPath,
      allowFailure: true,
      silent: true,
    },
  );

  if (result.exitCode !== 0) {
    return [];
  }

  return result.stdout
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
}

function getDirtyFiles(repoPath: string): string[] {
  const result = execCommand('git', ['status', '--short'], {
    cwd: repoPath,
    allowFailure: true,
    silent: true,
  });

  if (result.exitCode !== 0) {
    return [];
  }

  return result.stdout
    .split('\n')
    .map((line) => line.trimEnd())
    .filter((line) => line.trim().length > 0);
}

function isMergeInProgress(repoPath: string): boolean {
  return existsSync(getGitMetadataPath(repoPath, 'MERGE_HEAD'));
}

function isRebaseInProgress(repoPath: string): boolean {
  return (
    existsSync(getGitMetadataPath(repoPath, 'rebase-merge')) ||
    existsSync(getGitMetadataPath(repoPath, 'rebase-apply'))
  );
}

function isCherryPickInProgress(repoPath: string): boolean {
  return existsSync(getGitMetadataPath(repoPath, 'CHERRY_PICK_HEAD'));
}

function isRevertInProgress(repoPath: string): boolean {
  return existsSync(getGitMetadataPath(repoPath, 'REVERT_HEAD'));
}

function getAheadBehind(repoPath: string): { ahead: number; behind: number } {
  const result = execCommand(
    'git',
    ['rev-list', '--left-right', '--count', 'HEAD...@{upstream}'],
    {
      cwd: repoPath,
      allowFailure: true,
      silent: true,
    },
  );

  if (result.exitCode !== 0) {
    return { ahead: 0, behind: 0 };
  }

  const parts = result.stdout.trim().split(/\s+/);

  if (parts.length !== 2) {
    return { ahead: 0, behind: 0 };
  }

  const ahead = Number(parts[0]);
  const behind = Number(parts[1]);

  return {
    ahead: Number.isFinite(ahead) ? ahead : 0,
    behind: Number.isFinite(behind) ? behind : 0,
  };
}

function getRemoteOnlyCommits(
  repoPath: string,
  allowedAuthorEmails: string[],
): RemoteOnlyCommit[] {
  const result = execCommand(
    'git',
    ['log', 'HEAD..@{upstream}', '--format=%H%x09%an%x09%ae'],
    {
      cwd: repoPath,
      allowFailure: true,
      silent: true,
    },
  );

  if (result.exitCode !== 0) {
    return [];
  }

  const allowedEmails = new Set(
    allowedAuthorEmails.map((email) => email.trim().toLowerCase()),
  );

  return result.stdout
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .map((line) => {
      const [hash, authorName, authorEmail] = line.split('\t');
      const normalisedEmail = (authorEmail ?? '').trim().toLowerCase();

      return {
        hash: hash ?? '',
        authorName: authorName ?? '',
        authorEmail: authorEmail ?? '',
        isOurs: allowedEmails.has(normalisedEmail),
      };
    })
    .filter((commit) => commit.hash.length > 0);
}

function auditRepository(
  repo: LocalRepository,
  config: CliConfig,
): RepositoryAuditResult {
  try {
    fetchRepository(repo.absolutePath, config.verbose, config.dryRun);

    const dirtyFiles = getDirtyFiles(repo.absolutePath);
    const dirty = dirtyFiles.length > 0;

    const conflictFiles = getConflictFiles(repo.absolutePath);
    const mergeInProgress = isMergeInProgress(repo.absolutePath);
    const rebaseInProgress = isRebaseInProgress(repo.absolutePath);
    const cherryPickInProgress = isCherryPickInProgress(repo.absolutePath);
    const revertInProgress = isRevertInProgress(repo.absolutePath);

    const conflicted =
      conflictFiles.length > 0 ||
      mergeInProgress ||
      rebaseInProgress ||
      cherryPickInProgress ||
      revertInProgress;

    const { ahead, behind } = repo.upstreamRef
      ? getAheadBehind(repo.absolutePath)
      : { ahead: 0, behind: 0 };

    const remoteOnlyCommits = repo.upstreamRef
      ? getRemoteOnlyCommits(repo.absolutePath, config.allowedAuthorEmails)
      : [];

    const inSync = repo.upstreamRef !== null && ahead === 0 && behind === 0;
    const diverged = ahead > 0 && behind > 0;
    const stateOk = inSync && !dirty && !conflicted;

    return {
      name: repo.name,
      absolutePath: repo.absolutePath,
      upstreamRef: repo.upstreamRef,
      dirty,
      dirtyFiles,
      conflicted,
      conflictFiles,
      mergeInProgress,
      rebaseInProgress,
      cherryPickInProgress,
      revertInProgress,
      aheadCount: ahead,
      behindCount: behind,
      inSync,
      diverged,
      stateOk,
      remoteOnlyCommits,
      hasRemoteCommitsByOthers: remoteOnlyCommits.some(
        (commit) => !commit.isOurs,
      ),
      broken: false,
      brokenReason: null,
    };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);

    return {
      name: repo.name,
      absolutePath: repo.absolutePath,
      upstreamRef: repo.upstreamRef,
      dirty: false,
      dirtyFiles: [],
      conflicted: false,
      conflictFiles: [],
      mergeInProgress: false,
      rebaseInProgress: false,
      cherryPickInProgress: false,
      revertInProgress: false,
      aheadCount: 0,
      behindCount: 0,
      inSync: false,
      diverged: false,
      stateOk: false,
      remoteOnlyCommits: [],
      hasRemoteCommitsByOthers: false,
      broken: true,
      brokenReason: message,
    };
  }
}

function printBrokenAuditResult(repo: LocalRepository, reason: string): void {
  console.log(repo.name);
  console.log(`  upstream: ${repo.upstreamRef ?? 'none'}`);
  console.log('  state-ok: no');
  console.log('  in-sync: no');
  console.log('  dirty: no');
  console.log('  conflicted: no');
  console.log('  diverged: no');
  console.log('  ahead: 0');
  console.log('  behind: 0');
  console.log('  broken: yes');
  console.log('  remote-commits-by-others: no');
  console.log('  manual-check-required: yes');
  console.log(`  reason: ${reason.split('\n')[0]}`);
  console.log('');
}

function printAuditResult(
  result: RepositoryAuditResult,
  verbose: boolean,
): void {
  const isInteresting = requiresManualIntervention(result);

  if (!isInteresting && !verbose) {
    return;
  }

  console.log(result.name);
  console.log(`  upstream: ${result.upstreamRef ?? 'none'}`);
  console.log(`  state-ok: ${result.stateOk ? 'yes' : 'no'}`);
  console.log(`  in-sync: ${result.inSync ? 'yes' : 'no'}`);
  console.log(`  dirty: ${result.dirty ? 'yes' : 'no'}`);
  console.log(`  conflicted: ${result.conflicted ? 'yes' : 'no'}`);
  console.log(`  diverged: ${result.diverged ? 'yes' : 'no'}`);
  console.log(`  ahead: ${result.aheadCount}`);
  console.log(`  behind: ${result.behindCount}`);
  console.log(`  broken: ${result.broken ? 'yes' : 'no'}`);
  console.log(
    `  remote-commits-by-others: ${result.hasRemoteCommitsByOthers ? 'yes' : 'no'}`,
  );

  if (result.broken && result.brokenReason) {
    console.log('  manual-check-required: yes');
    console.log(`  reason: ${result.brokenReason.split('\n')[0]}`);
    console.log('');
    return;
  }

  if (result.mergeInProgress) {
    console.log('  merge-in-progress: yes');
  }

  if (result.rebaseInProgress) {
    console.log('  rebase-in-progress: yes');
  }

  if (result.cherryPickInProgress) {
    console.log('  cherry-pick-in-progress: yes');
  }

  if (result.revertInProgress) {
    console.log('  revert-in-progress: yes');
  }

  if (result.dirtyFiles.length > 0 && verbose) {
    console.log('  dirty-files:');
    for (const dirtyFile of result.dirtyFiles) {
      console.log(`    ${dirtyFile}`);
    }
  }

  if (result.conflictFiles.length > 0) {
    console.log(`  conflict-files: ${result.conflictFiles.join(', ')}`);
  }

  if (result.remoteOnlyCommits.length > 0) {
    console.log('  remote-only-commits:');
    for (const commit of result.remoteOnlyCommits) {
      console.log(
        `    ${commit.hash} ${commit.authorName} <${commit.authorEmail}> ours=${commit.isOurs ? 'yes' : 'no'}`,
      );
    }
  }

  console.log('');
}

function requiresManualIntervention(result: RepositoryAuditResult): boolean {
  return !result.stateOk || result.hasRemoteCommitsByOthers || result.broken;
}

async function fetchRemoteRepositories(
  config: CliConfig,
): Promise<GhRepositorySummary[]> {
  const args = [
    'repo',
    'list',
    config.owner,
    '--limit',
    '1000',
    '--json',
    [
      'name',
      'nameWithOwner',
      'description',
      'homepageUrl',
      'isArchived',
      'isFork',
      'url',
      'pushedAt',
      'visibility',
      'repositoryTopics',
      'latestRelease',
      'licenseInfo',
      'defaultBranchRef',
    ].join(','),
  ];

  if (!config.includeArchived) {
    args.push('--no-archived');
  }

  if (!config.includeForks) {
    args.push('--source');
  }

  for (const topic of config.topicFilters) {
    args.push('--topic', topic);
  }

  const result = execCommand('gh', args, {
    silent: !config.verbose,
  });

  const parsed = parseJson(result.stdout);

  if (!isGhRepositorySummaryArray(parsed)) {
    throw new Error(
      'Unexpected response while parsing GitHub repository list.',
    );
  }

  return parsed;
}

async function fetchRemoteRepositoryInventory(
  config: CliConfig,
): Promise<RepositoryInventoryRecord[]> {
  const repositories = await fetchRemoteRepositories(config);
  const inventory: RepositoryInventoryRecord[] = [];

  for (const repo of repositories) {
    const result = await runRepoOperationAsync(
      repo.nameWithOwner,
      'fetch-tags',
      async () => {
        return await fetchRepositoryTags(repo.nameWithOwner, config.verbose);
      },
    );

    inventory.push({
      repo,
      tags: result.ok && result.value ? result.value : [],
    });
  }

  return inventory;
}

async function fetchRepositoryTags(
  repository: string,
  verbose: boolean,
): Promise<GhRepositoryTag[]> {
  if (verbose) {
    log('debug', `Fetching tags for ${repository}`);
  }

  const result = execCommand(
    'gh',
    ['api', '--method', 'GET', `repos/${repository}/tags?per_page=100`],
    {
      allowFailure: true,
      silent: !verbose,
    },
  );

  if (result.exitCode !== 0) {
    return [];
  }

  const parsed = parseJson(result.stdout);

  if (!isGhRepositoryTagArray(parsed)) {
    return [];
  }

  return parsed;
}

function filterRepositoriesByTopics(
  repositories: GhRepositorySummary[],
  topicFilters: string[],
): GhRepositorySummary[] {
  if (topicFilters.length === 0) {
    return repositories;
  }

  const requiredTopics = new Set(
    topicFilters.map((topic) => topic.toLowerCase()),
  );

  return repositories.filter((repo) => {
    const repoTopics = new Set(
      (repo.repositoryTopics ?? []).map((topic) => topic.name.toLowerCase()),
    );

    for (const requiredTopic of requiredTopics) {
      if (!repoTopics.has(requiredTopic)) {
        return false;
      }
    }

    return true;
  });
}

async function cloneRepositoryIfMissing(
  repo: GhRepositorySummary,
  config: CliConfig,
): Promise<void> {
  const localPath = join(config.basePath, repo.name);

  if (existsSync(localPath)) {
    if (config.verbose) {
      log('debug', `Repository already exists locally: ${localPath}`);
    }
    return;
  }

  log('info', `Cloning ${repo.nameWithOwner} into ${localPath}`);

  if (config.dryRun) {
    return;
  }

  execCommand('gh', ['repo', 'clone', repo.nameWithOwner, localPath], {
    silent: !config.verbose,
  });
}

function parseJson(input: string): unknown {
  try {
    return JSON.parse(input) as unknown;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to parse JSON output: ${message}`);
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function isString(value: unknown): value is string {
  return typeof value === 'string';
}

function isBoolean(value: unknown): value is boolean {
  return typeof value === 'boolean';
}

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === 'string';
}

function isGhRepositorySummary(value: unknown): value is GhRepositorySummary {
  if (!isRecord(value)) {
    return false;
  }

  return (
    isString(value.name) &&
    isString(value.nameWithOwner) &&
    isNullableString(value.description) &&
    isNullableString(value.homepageUrl) &&
    isBoolean(value.isArchived) &&
    isBoolean(value.isFork) &&
    isString(value.url) &&
    isNullableString(value.pushedAt) &&
    isString(value.visibility)
  );
}

function isGhRepositorySummaryArray(
  value: unknown,
): value is GhRepositorySummary[] {
  return (
    Array.isArray(value) && value.every((item) => isGhRepositorySummary(item))
  );
}

function isGhRepositoryTag(value: unknown): value is GhRepositoryTag {
  if (!isRecord(value)) {
    return false;
  }

  if (
    !isString(value.name) ||
    !isString(value.zipball_url) ||
    !isString(value.tarball_url)
  ) {
    return false;
  }

  const commit = value.commit;

  if (!isRecord(commit)) {
    return false;
  }

  return isString(commit.sha) && isString(commit.url);
}

function isGhRepositoryTagArray(value: unknown): value is GhRepositoryTag[] {
  return Array.isArray(value) && value.every((item) => isGhRepositoryTag(item));
}

void main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[error] ${message}`);
  process.exit(1);
});
