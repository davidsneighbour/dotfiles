#!/usr/bin/env node
import { type ChildProcess, spawn, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import {
  createServer,
  type IncomingMessage,
  type ServerResponse,
} from "node:http";
import { homedir } from "node:os";
import { dirname, extname, join, resolve as resolvePath, sep } from "node:path";

const apiBase = "https://api.clockify.me/api/v1";
const configPath = join(homedir(), ".config", "dnb-clockify", "config.json");
const cacheDir = join(homedir(), ".cache", "dnb-clockify");
const statusCachePath = join(cacheDir, "status.json");
const nudgePath = join(cacheDir, "nudge.json");
const lastEntryPath = join(cacheDir, "last-entry.json");
const packageRoot = join(import.meta.dirname, "..");
const distWebDir = join(packageRoot, "dist", "web");
const staticContentTypes: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".svg": "image/svg+xml",
  ".woff2": "font/woff2",
  ".json": "application/json; charset=utf-8",
};

type OutputMode = "text" | "json";

type CliOptions = {
  json: boolean;
  verbose: boolean;
  quiet: boolean;
};

type ParsedArgs = {
  command: string;
  rest: string[];
  options: CliOptions;
};

type Config = {
  workspaceId?: string;
  aliases: Record<string, ProjectAlias>;
  settings: Settings;
};

type Settings = {
  cacheSeconds: number;
  nudgeMinutes: number;
  idleSeconds: number;
  formPort: number;
  lastEntryCacheSeconds: number;
};

type ProjectAlias = {
  id: string;
  name: string;
};

type ClockifyUser = {
  id: string;
  activeWorkspace?: string;
  defaultWorkspace?: string;
};

type ClockifyProject = {
  id: string;
  name: string;
  archived?: boolean;
  clientId?: string;
  color?: string;
  billable?: boolean;
  public?: boolean;
};

type ClockifyClient = {
  id: string;
  name: string;
  archived?: boolean;
};

type TimeInterval = {
  start: string;
  end?: string | null;
};

type ClockifyTimeEntry = {
  id: string;
  description?: string;
  projectId?: string;
  timeInterval: TimeInterval;
  tagIds?: string[];
};

type ClockifyTag = {
  id: string;
  name: string;
};

type FormContext = {
  token: string;
  workspaceId: string;
  config: Config;
  projects: ClockifyProject[];
  clients: ClockifyClient[];
  running: ClockifyTimeEntry | undefined;
  lastEntryEnd: string | null;
};

type FormPageContext = {
  projects: {
    id: string;
    name: string;
    clientId: string | undefined;
    color: string | undefined;
  }[];
  clients: { id: string; name: string }[];
  selectedProjectId: string | undefined;
  title: string;
  start: string;
  end: string;
  lastEntryEnd: string | null;
};

type FormSubmitPayload = {
  projectId: string;
  title: string;
  start: string;
  end: string;
};

type StatusState = "healthy" | "running" | "nudge" | "error";

type StatusData = {
  state: StatusState;
  label: string;
  colour: string;
  entry?: ClockifyTimeEntry;
  nudgeActiveSeconds: number;
  cached: boolean;
  error?: string;
};

type StatusCache = {
  createdAt: number;
  data: StatusData;
};

type NudgeState = {
  lastCheckedAt: number;
  activeSeconds: number;
};

type LastEntryCache = {
  createdAt: number;
  end: string | null;
};

class UserError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "UserError";
  }
}

const defaultSettings: Settings = {
  cacheSeconds: 30,
  nudgeMinutes: 60,
  idleSeconds: 300,
  formPort: 39241,
  lastEntryCacheSeconds: 3600,
};

function printHelp(): void {
  console.log(`Usage: dnb-clockify <command> [options]

Commands:
  status [--json]                         Show current tracking state.
  projects [--unmapped] [--json]          List Clockify projects.
  projects add --name <n> --client <c> [--color <hex>]
                                           Create a project.
  projects edit --id <id> [--name <n>] [--client <c>] [--color <hex>]
                                           Edit a project.
  projects remove --id <id>               Archive a project.
  client list                             List Clockify clients.
  client add --name <n>                   Create a client.
  client edit --id <id> --name <n>        Rename a client.
  client remove --id <id>                 Archive a client.
  start --project <project> --title <t>    Start a timer.
  stop [--project <project>] [--title <t>] Stop or update the running timer.
  add --project <project> --title <t> --start <time> --end <time>
                                           Create a completed entry.
  edit --id <entry-id> [--project <project>] [--title <t>] [--start <time>] [--end <time>]
                                           Edit an existing entry.
  prompt                                   Ask for fields in the terminal.
  form [--open] [--restart]                Start a local HTML form on 127.0.0.1.
  alias list                               List aliases and stale aliases.
  alias set --alias <short> --project <p>  Add or update an alias.
  alias remove --alias <short>             Remove an alias.
  alias configure                          Configure aliases interactively.

Global options:
  --json       Print machine-readable JSON.
  --verbose    Print more details where useful.
  --quiet      Suppress optional details.
  --help       Show this help.
`);
}

function parseArgs(argv: string[]): ParsedArgs {
  const rest: string[] = [];
  const options: CliOptions = { json: false, verbose: false, quiet: false };
  for (const arg of argv) {
    if (arg === "--json") {
      options.json = true;
    } else if (arg === "--verbose") {
      options.verbose = true;
    } else if (arg === "--quiet") {
      options.quiet = true;
    } else {
      rest.push(arg);
    }
  }
  const command = rest.shift() ?? "help";
  return { command, rest, options };
}

function getFlag(args: string[], name: string): string | undefined {
  const prefix = `${name}=`;
  for (let index = 0; index < args.length; index += 1) {
    const value = args[index];
    if (value === name) {
      return args[index + 1];
    }
    if (value?.startsWith(prefix)) {
      return value.slice(prefix.length);
    }
  }
  return undefined;
}

function hasFlag(args: string[], name: string): boolean {
  return args.includes(name);
}

function isAddressInUseError(error: unknown): boolean {
  return (
    error instanceof Error &&
    "code" in error &&
    (error as { code?: unknown }).code === "EADDRINUSE"
  );
}

function firstAvailableCommand(commands: string[]): string | undefined {
  for (const command of commands) {
    if (
      spawnSync("bash", ["-lc", `command -v ${command}`], { stdio: "ignore" })
        .status === 0
    ) {
      return command;
    }
  }
  return undefined;
}

function openUrl(url: string): void {
  const chrome = firstAvailableCommand([
    "google-chrome-stable",
    "google-chrome",
  ]);
  if (chrome === undefined) {
    spawn("xdg-open", [url], { detached: true, stdio: "ignore" }).unref();
    return;
  }

  spawn(
    chrome,
    [
      `--user-data-dir=${join(dirname(configPath), "chrome-profile")}`,
      "--class=dnb-clockify-form",
      "--name=dnb-clockify-form",
      `--app=${url}`,
    ],
    { detached: true, stdio: "ignore" },
  ).unref();
}

function refreshClockifyPolybar(): void {
  spawnSync("polybar-msg", ["action", "clockify", "hook", "0"], {
    stdio: "ignore",
  });
}

function killProcessOnPort(port: number): void {
  const result = spawnSync("lsof", ["-ti", `tcp:${port}`, "-sTCP:LISTEN"], {
    encoding: "utf8",
  });
  const pids = (result.stdout ?? "")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line !== "");
  for (const pid of pids) {
    spawnSync("kill", [pid], { stdio: "ignore" });
  }
}

function requireFlag(args: string[], name: string): string {
  const value = getFlag(args, name);
  if (value === undefined || value.trim() === "") {
    throw new UserError(`Missing required option: ${name}`);
  }
  return value;
}

async function readJsonFile<T>(path: string): Promise<T | undefined> {
  try {
    return JSON.parse(await readFile(path, "utf8")) as T;
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return undefined;
    }
    throw error;
  }
}

async function writeJsonFile(path: string, data: unknown): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  const temporaryPath = `${path}.tmp`;
  await writeFile(temporaryPath, `${JSON.stringify(data, null, 2)}\n`, "utf8");
  await rename(temporaryPath, path);
}

async function loadConfig(): Promise<Config> {
  const stored = await readJsonFile<Partial<Config>>(configPath);
  return {
    workspaceId: stored?.workspaceId,
    aliases: stored?.aliases ?? {},
    settings: { ...defaultSettings, ...(stored?.settings ?? {}) },
  };
}

async function saveConfig(config: Config): Promise<void> {
  await writeJsonFile(configPath, config);
}

async function readEnvToken(): Promise<string> {
  const existing = process.env.CLOCKIFY_TOKEN;
  if (existing !== undefined && existing.trim() !== "") {
    return existing.trim();
  }
  const envPath = join(homedir(), ".env");
  try {
    const content = await readFile(envPath, "utf8");
    for (const line of content.split(/\r?\n/)) {
      const match = /^CLOCKIFY_TOKEN=(.*)$/.exec(line.trim());
      if (match?.[1] !== undefined) {
        return match[1].replace(/^["']|["']$/g, "").trim();
      }
    }
  } catch (error) {
    if (
      !(error instanceof Error && "code" in error && error.code === "ENOENT")
    ) {
      throw error;
    }
  }
  throw new UserError(
    "CLOCKIFY_TOKEN is not set in the environment or ~/.env.",
  );
}

async function apiRequest<T>(
  token: string,
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const response = await fetch(`${apiBase}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      "X-Api-Key": token,
      ...(init.headers ?? {}),
    },
  });
  if (!response.ok) {
    const body = await response.text();
    throw new UserError(
      `Clockify API request failed (${response.status}): ${body || response.statusText}`,
    );
  }
  if (response.status === 204) {
    return undefined as T;
  }
  return (await response.json()) as T;
}

async function getUser(token: string): Promise<ClockifyUser> {
  return apiRequest<ClockifyUser>(token, "/user");
}

async function getWorkspaceId(token: string, config: Config): Promise<string> {
  if (config.workspaceId !== undefined && config.workspaceId.trim() !== "") {
    return config.workspaceId;
  }
  const user = await getUser(token);
  const workspaceId = user.activeWorkspace ?? user.defaultWorkspace;
  if (workspaceId === undefined) {
    throw new UserError(
      "Clockify did not return an active workspace. Set workspaceId in the config file.",
    );
  }
  return workspaceId;
}

async function getProjects(
  token: string,
  workspaceId: string,
): Promise<ClockifyProject[]> {
  return apiRequest<ClockifyProject[]>(
    token,
    `/workspaces/${workspaceId}/projects?archived=false&page-size=5000`,
  );
}

async function createProject(
  token: string,
  workspaceId: string,
  input: { name: string; clientId: string; color?: string },
): Promise<ClockifyProject> {
  return apiRequest<ClockifyProject>(
    token,
    `/workspaces/${workspaceId}/projects`,
    {
      method: "POST",
      body: JSON.stringify({
        name: input.name,
        clientId: input.clientId,
        ...(input.color === undefined ? {} : { color: input.color }),
      }),
    },
  );
}

async function updateProject(
  token: string,
  workspaceId: string,
  current: ClockifyProject,
  overrides: {
    name?: string;
    clientId?: string;
    color?: string;
    archived?: boolean;
  },
): Promise<ClockifyProject> {
  return apiRequest<ClockifyProject>(
    token,
    `/workspaces/${workspaceId}/projects/${current.id}`,
    {
      method: "PUT",
      body: JSON.stringify({
        name: overrides.name ?? current.name,
        archived: overrides.archived ?? current.archived ?? false,
        clientId: overrides.clientId ?? current.clientId,
        color: overrides.color ?? current.color,
        // Clockify's PUT rejects the request with a 403 if these are omitted,
        // even though they're not part of what this tool lets you edit.
        isPublic: current.public ?? true,
        billable: current.billable ?? true,
      }),
    },
  );
}

async function getClients(
  token: string,
  workspaceId: string,
): Promise<ClockifyClient[]> {
  return apiRequest<ClockifyClient[]>(
    token,
    `/workspaces/${workspaceId}/clients?archived=false&page-size=5000`,
  );
}

async function createClient(
  token: string,
  workspaceId: string,
  name: string,
): Promise<ClockifyClient> {
  return apiRequest<ClockifyClient>(
    token,
    `/workspaces/${workspaceId}/clients`,
    {
      method: "POST",
      body: JSON.stringify({ name }),
    },
  );
}

async function updateClient(
  token: string,
  workspaceId: string,
  current: ClockifyClient,
  overrides: { name?: string; archived?: boolean },
): Promise<ClockifyClient> {
  return apiRequest<ClockifyClient>(
    token,
    `/workspaces/${workspaceId}/clients/${current.id}`,
    {
      method: "PUT",
      body: JSON.stringify({
        name: overrides.name ?? current.name,
        archived: overrides.archived ?? current.archived ?? false,
      }),
    },
  );
}

async function resolveClient(
  token: string,
  workspaceId: string,
  value: string,
): Promise<ClockifyClient> {
  const clients = await getClients(token, workspaceId);
  const trimmed = value.trim();
  const byId = clients.find((client) => client.id === trimmed);
  if (byId !== undefined) {
    return byId;
  }
  const exact = clients.find((client) => client.name === trimmed);
  if (exact !== undefined) {
    return exact;
  }
  const matches = clients.filter(
    (client) => normaliseName(client.name) === normaliseName(trimmed),
  );
  if (matches.length === 1 && matches[0] !== undefined) {
    return matches[0];
  }
  if (matches.length > 1) {
    throw new UserError(
      `Client name "${value}" is ambiguous. Use the client ID.`,
    );
  }
  throw new UserError(`Client not found: ${value}`);
}

const viaFormTagName = "via:form";

async function getTags(
  token: string,
  workspaceId: string,
): Promise<ClockifyTag[]> {
  return apiRequest<ClockifyTag[]>(
    token,
    `/workspaces/${workspaceId}/tags?archived=false&page-size=5000`,
  );
}

async function createTag(
  token: string,
  workspaceId: string,
  name: string,
): Promise<ClockifyTag> {
  return apiRequest<ClockifyTag>(token, `/workspaces/${workspaceId}/tags`, {
    method: "POST",
    body: JSON.stringify({ name }),
  });
}

async function resolveViaFormTagId(
  token: string,
  workspaceId: string,
): Promise<string> {
  const tags = await getTags(token, workspaceId);
  const existing = tags.find((tag) => tag.name === viaFormTagName);
  if (existing !== undefined) {
    return existing.id;
  }
  const created = await createTag(token, workspaceId, viaFormTagName);
  return created.id;
}

async function getRunningEntry(
  token: string,
  workspaceId: string,
  userId: string,
): Promise<ClockifyTimeEntry | undefined> {
  const entries = await apiRequest<ClockifyTimeEntry[]>(
    token,
    `/workspaces/${workspaceId}/user/${userId}/time-entries?in-progress=true`,
  );
  return entries[0];
}

async function getRecentEntries(
  token: string,
  workspaceId: string,
  userId: string,
  pageSize: number,
): Promise<ClockifyTimeEntry[]> {
  return apiRequest<ClockifyTimeEntry[]>(
    token,
    `/workspaces/${workspaceId}/user/${userId}/time-entries?page-size=${pageSize}`,
  );
}

async function getCachedLastEntryEnd(
  token: string,
  workspaceId: string,
  userId: string,
  config: Config,
): Promise<string | null> {
  const cached = await readJsonFile<LastEntryCache>(lastEntryPath);
  const maxAgeMs = config.settings.lastEntryCacheSeconds * 1000;
  if (cached !== undefined && Date.now() - cached.createdAt <= maxAgeMs) {
    return cached.end;
  }
  const entries = await getRecentEntries(token, workspaceId, userId, 5);
  const lastCompleted = entries.find(
    (entry) =>
      entry.timeInterval.end !== undefined && entry.timeInterval.end !== null,
  );
  const end = lastCompleted?.timeInterval.end ?? null;
  await recordLastEntryEnd(end);
  return end;
}

async function recordLastEntryEnd(end: string | null): Promise<void> {
  await writeJsonFile(lastEntryPath, {
    createdAt: Date.now(),
    end,
  } satisfies LastEntryCache);
}

function normaliseName(value: string): string {
  return value.trim().toLowerCase();
}

function projectDisplay(project: ClockifyProject, config: Config): string {
  const alias = Object.entries(config.aliases).find(
    ([, item]) => item.id === project.id,
  )?.[0];
  return alias === undefined ? project.name : `${alias} - ${project.name}`;
}

async function resolveProject(
  token: string,
  workspaceId: string,
  config: Config,
  value: string,
): Promise<ClockifyProject> {
  const projects = await getProjects(token, workspaceId);
  const trimmed = value.trim();
  const alias = config.aliases[trimmed];
  if (alias !== undefined) {
    const project = projects.find((candidate) => candidate.id === alias.id);
    if (project === undefined) {
      throw new UserError(
        `Alias "${trimmed}" points to a project ID that no longer exists: ${alias.id}`,
      );
    }
    return project;
  }
  const byId = projects.find((project) => project.id === trimmed);
  if (byId !== undefined) {
    return byId;
  }
  const exact = projects.find((project) => project.name === trimmed);
  if (exact !== undefined) {
    return exact;
  }
  const matches = projects.filter(
    (project) => normaliseName(project.name) === normaliseName(trimmed),
  );
  if (matches.length === 1 && matches[0] !== undefined) {
    return matches[0];
  }
  if (matches.length > 1) {
    throw new UserError(
      `Project name "${value}" is ambiguous. Use an alias or project ID.`,
    );
  }
  throw new UserError(`Project not found: ${value}`);
}

function parseTimeInput(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new UserError(`Invalid date/time: ${value}`);
  }
  return date.toISOString();
}

function localDateInputValue(value: Date): string {
  const offsetMs = value.getTimezoneOffset() * 60_000;
  return new Date(value.getTime() - offsetMs).toISOString().slice(0, 16);
}

async function createEntry(
  token: string,
  workspaceId: string,
  projectId: string,
  title: string,
  start: string,
  end?: string,
  tagIds?: string[],
): Promise<ClockifyTimeEntry> {
  return apiRequest<ClockifyTimeEntry>(
    token,
    `/workspaces/${workspaceId}/time-entries`,
    {
      method: "POST",
      body: JSON.stringify({
        description: title,
        projectId,
        start,
        ...(end === undefined ? {} : { end }),
        ...(tagIds === undefined ? {} : { tagIds }),
      }),
    },
  );
}

async function updateEntry(
  token: string,
  workspaceId: string,
  entryId: string,
  data: {
    projectId?: string;
    title?: string;
    start?: string;
    end?: string | null;
    tagIds?: string[];
  },
): Promise<ClockifyTimeEntry> {
  return apiRequest<ClockifyTimeEntry>(
    token,
    `/workspaces/${workspaceId}/time-entries/${entryId}`,
    {
      method: "PUT",
      body: JSON.stringify({
        ...(data.title === undefined ? {} : { description: data.title }),
        ...(data.projectId === undefined ? {} : { projectId: data.projectId }),
        ...(data.start === undefined ? {} : { start: data.start }),
        ...(data.end === undefined ? {} : { end: data.end }),
        ...(data.tagIds === undefined ? {} : { tagIds: data.tagIds }),
      }),
    },
  );
}

async function stopEntry(
  token: string,
  workspaceId: string,
  entry: ClockifyTimeEntry,
  end: string,
): Promise<ClockifyTimeEntry> {
  return updateEntry(token, workspaceId, entry.id, {
    start: entry.timeInterval.start,
    end,
  });
}

function success(command: string, data: unknown, mode: OutputMode): void {
  if (mode === "json") {
    console.log(JSON.stringify({ ok: true, command, data }, null, 2));
  }
}

function errorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error && error.message.trim() !== "") {
    return error.message;
  }
  const message = String(error).trim();
  return message === "" ? fallback : message;
}

function printError(command: string, error: unknown, mode: OutputMode): void {
  const message = errorMessage(error, "Clockify command failed.");
  if (mode === "json") {
    console.log(
      JSON.stringify({ ok: false, command, error: message }, null, 2),
    );
    return;
  }
  console.error(`Error: ${message}`);
}

async function commandProjects(
  args: string[],
  options: CliOptions,
): Promise<void> {
  const subcommand = args[0];
  if (
    subcommand === "add" ||
    subcommand === "edit" ||
    subcommand === "remove"
  ) {
    await commandProjectMutate(subcommand, args.slice(1), options);
    return;
  }
  const token = await readEnvToken();
  const config = await loadConfig();
  const workspaceId = await getWorkspaceId(token, config);
  const projects = await getProjects(token, workspaceId);
  const mappedIds = new Set(
    Object.values(config.aliases).map((alias) => alias.id),
  );
  const filtered = hasFlag(args, "--unmapped")
    ? projects.filter((project) => !mappedIds.has(project.id))
    : projects;
  const data = filtered.map((project) => ({
    id: project.id,
    name: project.name,
    alias: Object.entries(config.aliases).find(
      ([, alias]) => alias.id === project.id,
    )?.[0],
  }));
  if (options.json) {
    success("projects", data, "json");
    return;
  }
  for (const project of data) {
    console.log(`${project.alias ?? "-"}\t${project.name}\t${project.id}`);
  }
}

async function commandProjectMutate(
  subcommand: "add" | "edit" | "remove",
  args: string[],
  options: CliOptions,
): Promise<void> {
  const token = await readEnvToken();
  const config = await loadConfig();
  const workspaceId = await getWorkspaceId(token, config);
  if (subcommand === "add") {
    const name = requireFlag(args, "--name");
    const client = await resolveClient(
      token,
      workspaceId,
      requireFlag(args, "--client"),
    );
    const project = await createProject(token, workspaceId, {
      name,
      clientId: client.id,
      color: getFlag(args, "--color"),
    });
    if (options.json) {
      success("projects add", project, "json");
      return;
    }
    console.log(`Added project: ${project.name}`);
    return;
  }
  const id = requireFlag(args, "--id");
  const projects = await getProjects(token, workspaceId);
  const current = projects.find((project) => project.id === id);
  if (current === undefined) {
    throw new UserError(`Project not found: ${id}`);
  }
  if (subcommand === "remove") {
    const project = await updateProject(token, workspaceId, current, {
      archived: true,
    });
    if (options.json) {
      success("projects remove", project, "json");
      return;
    }
    console.log(`Archived project: ${project.name}`);
    return;
  }
  const clientInput = getFlag(args, "--client");
  const clientId =
    clientInput === undefined
      ? undefined
      : (await resolveClient(token, workspaceId, clientInput)).id;
  const project = await updateProject(token, workspaceId, current, {
    name: getFlag(args, "--name"),
    clientId,
    color: getFlag(args, "--color"),
  });
  if (options.json) {
    success("projects edit", project, "json");
    return;
  }
  console.log(`Updated project: ${project.name}`);
}

async function commandClient(
  args: string[],
  options: CliOptions,
): Promise<void> {
  const subcommand = args[0] ?? "list";
  const token = await readEnvToken();
  const config = await loadConfig();
  const workspaceId = await getWorkspaceId(token, config);
  if (subcommand === "add") {
    const client = await createClient(
      token,
      workspaceId,
      requireFlag(args, "--name"),
    );
    if (options.json) {
      success("client add", client, "json");
      return;
    }
    console.log(`Added client: ${client.name}`);
    return;
  }
  if (subcommand === "edit" || subcommand === "remove") {
    const id = requireFlag(args, "--id");
    const clients = await getClients(token, workspaceId);
    const current = clients.find((client) => client.id === id);
    if (current === undefined) {
      throw new UserError(`Client not found: ${id}`);
    }
    const client =
      subcommand === "remove"
        ? await updateClient(token, workspaceId, current, { archived: true })
        : await updateClient(token, workspaceId, current, {
            name: getFlag(args, "--name"),
          });
    if (options.json) {
      success(`client ${subcommand}`, client, "json");
      return;
    }
    console.log(
      subcommand === "remove"
        ? `Archived client: ${client.name}`
        : `Updated client: ${client.name}`,
    );
    return;
  }
  const clients = await getClients(token, workspaceId);
  if (options.json) {
    success("client list", clients, "json");
    return;
  }
  for (const client of clients) {
    console.log(`${client.id}\t${client.name}`);
  }
}

async function computeStatus(useCache: boolean): Promise<StatusData> {
  const token = await readEnvToken();
  const config = await loadConfig();
  if (useCache) {
    const cached = await readJsonFile<StatusCache>(statusCachePath);
    const maxAgeMs = config.settings.cacheSeconds * 1000;
    if (cached !== undefined && Date.now() - cached.createdAt <= maxAgeMs) {
      return { ...cached.data, cached: true };
    }
  }
  const user = await getUser(token);
  const workspaceId = await getWorkspaceId(token, config);
  const entry = await getRunningEntry(token, workspaceId, user.id);
  const nudgeActiveSeconds = await updateNudge(
    entry === undefined,
    config.settings,
  );
  const thresholdSeconds = config.settings.nudgeMinutes * 60;
  const data: StatusData =
    entry === undefined
      ? nudgeActiveSeconds >= thresholdSeconds
        ? {
            state: "nudge",
            label: "tracking nudge",
            colour: "#f1fa8c",
            nudgeActiveSeconds,
            cached: false,
          }
        : {
            state: "healthy",
            label: "not tracking",
            colour: "#50fa7b",
            nudgeActiveSeconds,
            cached: false,
          }
      : {
          state: "running",
          label:
            entry.description === undefined || entry.description === ""
              ? "tracking"
              : entry.description,
          colour: "#ff5555",
          entry,
          nudgeActiveSeconds: 0,
          cached: false,
        };
  await writeJsonFile(statusCachePath, {
    createdAt: Date.now(),
    data,
  } satisfies StatusCache);
  return data;
}

async function updateNudge(
  noTimer: boolean,
  settings: Settings,
): Promise<number> {
  const now = Date.now();
  const previous = (await readJsonFile<NudgeState>(nudgePath)) ?? {
    lastCheckedAt: now,
    activeSeconds: 0,
  };
  if (!noTimer) {
    await writeJsonFile(nudgePath, {
      lastCheckedAt: now,
      activeSeconds: 0,
    } satisfies NudgeState);
    return 0;
  }
  const elapsedSeconds = Math.max(
    0,
    Math.min(600, Math.floor((now - previous.lastCheckedAt) / 1000)),
  );
  const idleSeconds = readIdleSeconds();
  const activeIncrement =
    idleSeconds === undefined || idleSeconds < settings.idleSeconds
      ? elapsedSeconds
      : 0;
  const next = {
    lastCheckedAt: now,
    activeSeconds: previous.activeSeconds + activeIncrement,
  } satisfies NudgeState;
  await writeJsonFile(nudgePath, next);
  return next.activeSeconds;
}

function readIdleSeconds(): number | undefined {
  const result = spawnSync("xprintidle", [], { encoding: "utf8" });
  if (result.status !== 0) {
    return undefined;
  }
  const idleMs = Number.parseInt(result.stdout.trim(), 10);
  return Number.isFinite(idleMs) ? Math.floor(idleMs / 1000) : undefined;
}

async function commandStatus(options: CliOptions): Promise<void> {
  try {
    const data = await computeStatus(true);
    if (options.json) {
      success("status", data, "json");
      return;
    }
    const dot =
      data.state === "running"
        ? "red"
        : data.state === "nudge"
          ? "yellow"
          : "green";
    console.log(`${dot}: ${data.label}`);
  } catch (error) {
    const data: StatusData = {
      state: "error",
      label: error instanceof Error ? error.message : String(error),
      colour: "#bd93f9",
      nudgeActiveSeconds: 0,
      cached: false,
      error: error instanceof Error ? error.message : String(error),
    };
    await writeJsonFile(statusCachePath, {
      createdAt: Date.now(),
      data,
    } satisfies StatusCache);
    if (options.json) {
      success("status", data, "json");
      return;
    }
    console.log(`error: ${data.label}`);
  }
}

async function commandStart(
  args: string[],
  options: CliOptions,
): Promise<void> {
  const token = await readEnvToken();
  const config = await loadConfig();
  const workspaceId = await getWorkspaceId(token, config);
  const project = await resolveProject(
    token,
    workspaceId,
    config,
    requireFlag(args, "--project"),
  );
  const title = requireFlag(args, "--title");
  const entry = await createEntry(
    token,
    workspaceId,
    project.id,
    title,
    new Date().toISOString(),
  );
  await clearStatusCache();
  if (options.json) {
    success("start", entry, "json");
    return;
  }
  console.log(`Started: ${title}`);
}

async function commandStop(args: string[], options: CliOptions): Promise<void> {
  const token = await readEnvToken();
  const config = await loadConfig();
  const user = await getUser(token);
  const workspaceId = await getWorkspaceId(token, config);
  const running = await getRunningEntry(token, workspaceId, user.id);
  if (running === undefined) {
    throw new UserError("No running Clockify timer found.");
  }
  const title = getFlag(args, "--title");
  const projectInput = getFlag(args, "--project");
  if (title !== undefined || projectInput !== undefined) {
    const project =
      projectInput === undefined
        ? undefined
        : await resolveProject(token, workspaceId, config, projectInput);
    await updateEntry(token, workspaceId, running.id, {
      title,
      projectId: project?.id,
      start: running.timeInterval.start,
      end: null,
    });
  }
  const entry = await stopEntry(
    token,
    workspaceId,
    running,
    new Date().toISOString(),
  );
  await clearStatusCache();
  if (options.json) {
    success("stop", entry, "json");
    return;
  }
  console.log("Stopped running timer.");
}

async function commandAdd(args: string[], options: CliOptions): Promise<void> {
  const token = await readEnvToken();
  const config = await loadConfig();
  const workspaceId = await getWorkspaceId(token, config);
  const project = await resolveProject(
    token,
    workspaceId,
    config,
    requireFlag(args, "--project"),
  );
  const title = requireFlag(args, "--title");
  const start = parseTimeInput(requireFlag(args, "--start"));
  const end = parseTimeInput(requireFlag(args, "--end"));
  const entry = await createEntry(
    token,
    workspaceId,
    project.id,
    title,
    start,
    end,
  );
  await clearStatusCache();
  if (options.json) {
    success("add", entry, "json");
    return;
  }
  console.log(`Added: ${title}`);
}

async function commandEdit(args: string[], options: CliOptions): Promise<void> {
  const token = await readEnvToken();
  const config = await loadConfig();
  const workspaceId = await getWorkspaceId(token, config);
  const entryId = requireFlag(args, "--id");
  const projectInput = getFlag(args, "--project");
  const project =
    projectInput === undefined
      ? undefined
      : await resolveProject(token, workspaceId, config, projectInput);
  const entry = await updateEntry(token, workspaceId, entryId, {
    projectId: project?.id,
    title: getFlag(args, "--title"),
    start:
      getFlag(args, "--start") === undefined
        ? undefined
        : parseTimeInput(requireFlag(args, "--start")),
    end:
      getFlag(args, "--end") === undefined
        ? undefined
        : parseTimeInput(requireFlag(args, "--end")),
  });
  await clearStatusCache();
  if (options.json) {
    success("edit", entry, "json");
    return;
  }
  console.log(`Updated entry: ${entry.id}`);
}

async function clearStatusCache(): Promise<void> {
  await writeJsonFile(nudgePath, {
    lastCheckedAt: Date.now(),
    activeSeconds: 0,
  } satisfies NudgeState);
  await writeJsonFile(statusCachePath, {
    createdAt: 0,
    data: {
      state: "healthy",
      label: "expired",
      colour: "#50fa7b",
      nudgeActiveSeconds: 0,
      cached: true,
    },
  });
}

function staleAliases(
  projects: ClockifyProject[],
  config: Config,
): Array<{
  alias: string;
  id: string;
  cachedName: string;
  currentName?: string;
  stale: boolean;
}> {
  return Object.entries(config.aliases).map(([alias, item]) => {
    const project = projects.find((candidate) => candidate.id === item.id);
    return {
      alias,
      id: item.id,
      cachedName: item.name,
      currentName: project?.name,
      stale: project === undefined || project.name !== item.name,
    };
  });
}

async function commandAlias(
  args: string[],
  options: CliOptions,
): Promise<void> {
  const subcommand = args[0] ?? "list";
  const token = await readEnvToken();
  const config = await loadConfig();
  const workspaceId = await getWorkspaceId(token, config);
  if (subcommand === "set") {
    const alias = requireFlag(args, "--alias");
    const project = await resolveProject(
      token,
      workspaceId,
      config,
      requireFlag(args, "--project"),
    );
    config.aliases[alias] = { id: project.id, name: project.name };
    await saveConfig(config);
    if (options.json) {
      success("alias set", { alias, project }, "json");
      return;
    }
    console.log(`Set ${alias} -> ${project.name}`);
    return;
  }
  if (subcommand === "remove") {
    const alias = requireFlag(args, "--alias");
    delete config.aliases[alias];
    await saveConfig(config);
    if (options.json) {
      success("alias remove", { alias }, "json");
      return;
    }
    console.log(`Removed alias: ${alias}`);
    return;
  }
  if (subcommand === "configure") {
    await commandAliasConfigure(options);
    return;
  }
  const projects = await getProjects(token, workspaceId);
  const data = staleAliases(projects, config);
  if (options.json) {
    success("alias list", data, "json");
    return;
  }
  for (const alias of data) {
    const marker = alias.stale ? "stale" : "ok";
    console.log(`${alias.alias}\t${marker}\t${alias.cachedName}\t${alias.id}`);
  }
}

async function commandAliasConfigure(options: CliOptions): Promise<void> {
  const token = await readEnvToken();
  const config = await loadConfig();
  const workspaceId = await getWorkspaceId(token, config);
  const projects = await getProjects(token, workspaceId);
  const project = await chooseProject(
    projects,
    config,
    "Select project to alias",
  );
  const alias = await promptText(
    "Alias",
    Object.entries(config.aliases).find(
      ([, item]) => item.id === project.id,
    )?.[0] ?? "",
  );
  if (alias.trim() === "") {
    throw new UserError("Alias must not be empty.");
  }
  config.aliases[alias.trim()] = { id: project.id, name: project.name };
  await saveConfig(config);
  if (options.json) {
    success("alias configure", { alias, project }, "json");
    return;
  }
  console.log(`Set ${alias.trim()} -> ${project.name}`);
}

async function commandPrompt(options: CliOptions): Promise<void> {
  const status = await computeStatus(false);
  const mode = await choose(
    ["start", "stop", "add"],
    status.state === "running" ? "stop" : "start",
    "Action",
  );
  if (mode === "stop") {
    await commandStop([], options);
    return;
  }
  const token = await readEnvToken();
  const config = await loadConfig();
  const workspaceId = await getWorkspaceId(token, config);
  const projects = await getProjects(token, workspaceId);
  const project = await chooseProject(projects, config, "Project");
  const title = await promptText("Title", "");
  if (mode === "add") {
    const start = await promptText("Start", localDateInputValue(new Date()));
    const end = await promptText("End", localDateInputValue(new Date()));
    const entry = await createEntry(
      token,
      workspaceId,
      project.id,
      title,
      parseTimeInput(start),
      parseTimeInput(end),
    );
    await clearStatusCache();
    if (options.json) {
      success("prompt", entry, "json");
      return;
    }
    console.log(`Added: ${title}`);
    return;
  }
  const entry = await createEntry(
    token,
    workspaceId,
    project.id,
    title,
    new Date().toISOString(),
  );
  await clearStatusCache();
  if (options.json) {
    success("prompt", entry, "json");
    return;
  }
  console.log(`Started: ${title}`);
}

async function chooseProject(
  projects: ClockifyProject[],
  config: Config,
  prompt: string,
): Promise<ClockifyProject> {
  const labels = projects.map((project) => projectDisplay(project, config));
  const selected = await choose(labels, labels[0] ?? "", prompt);
  const index = labels.indexOf(selected);
  const project = projects[index];
  if (project === undefined) {
    throw new UserError("No project selected.");
  }
  return project;
}

async function choose(
  choices: string[],
  defaultValue: string,
  prompt: string,
): Promise<string> {
  if (choices.length === 0) {
    throw new UserError(`No choices available for ${prompt}.`);
  }
  if (hasCommand("gum")) {
    const child = spawn("gum", ["filter", "--placeholder", prompt], {
      stdio: ["pipe", "pipe", "inherit"],
    });
    child.stdin?.write(`${choices.join("\n")}\n`);
    child.stdin?.end();
    const output = await collectChildOutput(child);
    return output.trim() || defaultValue;
  }
  console.error(`${prompt}:`);
  choices.forEach((choice, index) => console.error(`${index + 1}. ${choice}`));
  const answer = await promptText("Number", "1");
  const index = Number.parseInt(answer, 10) - 1;
  return choices[index] ?? defaultValue;
}

async function promptText(
  prompt: string,
  defaultValue: string,
): Promise<string> {
  if (hasCommand("gum")) {
    const args = ["input", "--placeholder", prompt];
    if (defaultValue !== "") {
      args.push("--value", defaultValue);
    }
    const child = spawn("gum", args, { stdio: ["inherit", "pipe", "inherit"] });
    const output = await collectChildOutput(child);
    return output.trim();
  }
  process.stderr.write(
    `${prompt}${defaultValue === "" ? "" : ` [${defaultValue}]`}: `,
  );
  const input = await new Promise<string>((resolve) => {
    process.stdin.once("data", (data: Buffer) =>
      resolve(data.toString("utf8").trim()),
    );
  });
  return input === "" ? defaultValue : input;
}

function hasCommand(command: string): boolean {
  return (
    spawnSync("bash", ["-lc", `command -v ${command}`], { stdio: "ignore" })
      .status === 0
  );
}

async function collectChildOutput(child: ChildProcess): Promise<string> {
  let output = "";
  child.stdout?.on("data", (chunk: Buffer) => {
    output += chunk.toString("utf8");
  });
  const code = await new Promise<number | null>((resolve) =>
    child.on("close", resolve),
  );
  if (code !== 0) {
    throw new UserError("Interactive selection was cancelled.");
  }
  return output;
}

async function loadFormContext(config: Config): Promise<FormContext> {
  const token = await readEnvToken();
  const user = await getUser(token);
  const workspaceId = await getWorkspaceId(token, config);
  const projects = await getProjects(token, workspaceId);
  const clients = await getClients(token, workspaceId);
  const running = await getRunningEntry(token, workspaceId, user.id);
  const lastEntryEnd = await getCachedLastEntryEnd(
    token,
    workspaceId,
    user.id,
    config,
  );

  return {
    token,
    workspaceId,
    config,
    projects,
    clients,
    running,
    lastEntryEnd,
  };
}

async function refreshFormLists(formContext: FormContext): Promise<void> {
  formContext.clients = await getClients(
    formContext.token,
    formContext.workspaceId,
  );
  formContext.projects = await getProjects(
    formContext.token,
    formContext.workspaceId,
  );
}

function sendJson(response: ServerResponse, data: unknown): void {
  response.setHeader("content-type", "application/json; charset=utf-8");
  response.end(JSON.stringify(data));
}

async function handleClientCreate(
  request: IncomingMessage,
  formContext: FormContext,
): Promise<void> {
  const body = JSON.parse(await readRequestBody(request)) as {
    name?: string;
  };
  const name = (body.name ?? "").trim();
  if (name === "") {
    throw new UserError("Client name is required.");
  }
  await createClient(formContext.token, formContext.workspaceId, name);
  await refreshFormLists(formContext);
}

async function handleClientUpdate(
  request: IncomingMessage,
  formContext: FormContext,
): Promise<void> {
  const body = JSON.parse(await readRequestBody(request)) as {
    id?: string;
    name?: string;
    archived?: boolean;
  };
  const current = formContext.clients.find((client) => client.id === body.id);
  if (current === undefined) {
    throw new UserError("Client not found.");
  }
  await updateClient(formContext.token, formContext.workspaceId, current, {
    name: body.name,
    archived: body.archived,
  });
  await refreshFormLists(formContext);
}

async function handleProjectCreate(
  request: IncomingMessage,
  formContext: FormContext,
): Promise<void> {
  const body = JSON.parse(await readRequestBody(request)) as {
    name?: string;
    clientId?: string;
    color?: string;
  };
  const name = (body.name ?? "").trim();
  const clientId = (body.clientId ?? "").trim();
  if (name === "") {
    throw new UserError("Project name is required.");
  }
  if (clientId === "") {
    throw new UserError("Client is required.");
  }
  await createProject(formContext.token, formContext.workspaceId, {
    name,
    clientId,
    color: body.color,
  });
  await refreshFormLists(formContext);
}

async function handleProjectUpdate(
  request: IncomingMessage,
  formContext: FormContext,
): Promise<void> {
  const body = JSON.parse(await readRequestBody(request)) as {
    id?: string;
    name?: string;
    clientId?: string;
    color?: string;
    archived?: boolean;
  };
  const current = formContext.projects.find(
    (project) => project.id === body.id,
  );
  if (current === undefined) {
    throw new UserError("Project not found.");
  }
  await updateProject(formContext.token, formContext.workspaceId, current, {
    name: body.name,
    clientId: body.clientId,
    color: body.color,
    archived: body.archived,
  });
  await refreshFormLists(formContext);
}

async function restartFormDetached(
  args: string[],
  options: CliOptions,
  config: Config,
): Promise<void> {
  const childArgs = [
    "--experimental-strip-types",
    join(import.meta.dirname, "cli.ts"),
    "form",
    ...(hasFlag(args, "--open") ? ["--open"] : []),
  ];
  spawn(process.execPath, childArgs, {
    detached: true,
    stdio: "ignore",
  }).unref();

  const url = `http://127.0.0.1:${config.settings.formPort}/`;
  const token = await readEnvToken();
  const user = await getUser(token);
  const workspaceId = await getWorkspaceId(token, config);
  const running = await getRunningEntry(token, workspaceId, user.id);
  if (options.json) {
    success("form", { url, running: running !== undefined }, "json");
    return;
  }
  console.log(url);
  console.log(
    running !== undefined
      ? `Timer running: ${running.description || "(untitled)"}`
      : "No timer running.",
  );
}

async function commandForm(args: string[], options: CliOptions): Promise<void> {
  const config = await loadConfig();
  if (!existsSync(join(distWebDir, "index.html"))) {
    throw new UserError(
      "Clockify form assets are not built. Run 'npm run build' in tools/clockify first.",
    );
  }
  if (hasFlag(args, "--restart")) {
    killProcessOnPort(config.settings.formPort);
    await new Promise<void>((resolve) => {
      setTimeout(resolve, 300);
    });
    await restartFormDetached(args, options, config);
    return;
  }
  let context: Promise<FormContext> | undefined;
  const getFormContext = (): Promise<FormContext> => {
    context ??= loadFormContext(config);
    return context;
  };
  const server = createServer(async (request, response) => {
    const url = new URL(request.url ?? "/", "http://127.0.0.1");
    try {
      if (request.method === "POST" && url.pathname === "/api/submit") {
        const formContext = await getFormContext();
        await submitFormEntry(request, formContext);
        sendJson(response, { ok: true });
        server.close();
        return;
      }
      if (request.method === "POST" && url.pathname === "/api/clients/create") {
        const formContext = await getFormContext();
        await handleClientCreate(request, formContext);
        sendJson(response, {
          ok: true,
          clients: formContext.clients,
          projects: formContext.projects,
        });
        return;
      }
      if (request.method === "POST" && url.pathname === "/api/clients/update") {
        const formContext = await getFormContext();
        await handleClientUpdate(request, formContext);
        sendJson(response, {
          ok: true,
          clients: formContext.clients,
          projects: formContext.projects,
        });
        return;
      }
      if (
        request.method === "POST" &&
        url.pathname === "/api/projects/create"
      ) {
        const formContext = await getFormContext();
        await handleProjectCreate(request, formContext);
        sendJson(response, {
          ok: true,
          clients: formContext.clients,
          projects: formContext.projects,
        });
        return;
      }
      if (
        request.method === "POST" &&
        url.pathname === "/api/projects/update"
      ) {
        const formContext = await getFormContext();
        await handleProjectUpdate(request, formContext);
        sendJson(response, {
          ok: true,
          clients: formContext.clients,
          projects: formContext.projects,
        });
        return;
      }
      if (request.method === "GET" && url.pathname === "/") {
        const formContext = await getFormContext();
        await serveFormPage(response, formContext);
        return;
      }
      if (
        request.method === "GET" &&
        (await serveStaticFile(response, join(distWebDir, url.pathname)))
      ) {
        return;
      }
      response.statusCode = 404;
      response.end("Not found");
    } catch (error) {
      const isUserError = error instanceof UserError;
      if (!isUserError) {
        console.error("Clockify form request failed.", error);
      }
      const message = isUserError
        ? errorMessage(error, "Clockify form request failed.")
        : "Clockify form request failed.";
      if (request.method === "POST") {
        response.statusCode = isUserError ? 400 : 502;
        response.setHeader("content-type", "application/json; charset=utf-8");
        response.end(JSON.stringify({ ok: false, error: message }));
        return;
      }
      response.statusCode = 500;
      sendHtml(response, `<h1>Error</h1><p>${escapeHtml(message)}</p>`);
    }
  });
  const configuredUrl = `http://127.0.0.1:${config.settings.formPort}/`;
  try {
    await new Promise<void>((resolve, reject) => {
      server.once("error", reject);
      server.listen(config.settings.formPort, "127.0.0.1", () => {
        server.off("error", reject);
        resolve();
      });
    });
  } catch (error) {
    if (isAddressInUseError(error)) {
      if (hasFlag(args, "--open")) {
        openUrl(configuredUrl);
      }
      if (options.json) {
        success("form", { url: configuredUrl, existing: true }, "json");
      } else {
        console.log(configuredUrl);
      }
      return;
    }
    throw error;
  }
  const address = server.address();
  const port =
    typeof address === "object" && address !== null
      ? address.port
      : config.settings.formPort;
  const url = `http://127.0.0.1:${port}/`;
  const formContext = await getFormContext();
  const running = formContext.running !== undefined;
  if (hasFlag(args, "--open")) {
    openUrl(url);
  }
  if (options.json) {
    success("form", { url, running }, "json");
  } else {
    console.log(url);
    console.log(
      running
        ? `Timer running: ${formContext.running?.description || "(untitled)"}`
        : "No timer running.",
    );
  }
}

async function submitFormEntry(
  request: IncomingMessage,
  formContext: FormContext,
): Promise<void> {
  const { token, workspaceId, running, config } = formContext;
  const body = await readRequestBody(request);
  const payload = JSON.parse(body) as Partial<FormSubmitPayload>;
  const project = await resolveProject(
    token,
    workspaceId,
    config,
    payload.projectId ?? "",
  );
  const title = payload.title ?? "";
  const start = parseTimeInput(payload.start ?? "");
  const endValue = payload.end ?? "";
  if (running === undefined) {
    const end = endValue.trim() === "" ? undefined : parseTimeInput(endValue);
    const tagId = await resolveViaFormTagId(token, workspaceId);
    await createEntry(token, workspaceId, project.id, title, start, end, [
      tagId,
    ]);
    if (end !== undefined) {
      await recordLastEntryEnd(end);
    }
  } else if (endValue.trim() === "") {
    await updateEntry(token, workspaceId, running.id, {
      projectId: project.id,
      title,
      start,
      end: null,
    });
  } else {
    const end = parseTimeInput(endValue);
    const tagId = await resolveViaFormTagId(token, workspaceId);
    const tagIds = [...new Set([...(running.tagIds ?? []), tagId])];
    await updateEntry(token, workspaceId, running.id, {
      projectId: project.id,
      title,
      start,
      end,
      tagIds,
    });
    await recordLastEntryEnd(end);
  }
  await clearStatusCache();
  refreshClockifyPolybar();
}

async function readRequestBody(request: IncomingMessage): Promise<string> {
  let body = "";
  for await (const chunk of request) {
    body += chunk.toString();
  }
  return body;
}

function buildFormPageContext(formContext: FormContext): FormPageContext {
  const { projects, clients, config, running, lastEntryEnd } = formContext;
  const now = new Date();
  const start =
    running?.timeInterval.start === undefined
      ? localDateInputValue(now)
      : localDateInputValue(new Date(running.timeInterval.start));
  const end = running === undefined ? "" : localDateInputValue(now);
  return {
    projects: projects.map((project) => ({
      id: project.id,
      name: projectDisplay(project, config),
      clientId: project.clientId,
      color: project.color,
    })),
    clients: clients.map((client) => ({ id: client.id, name: client.name })),
    selectedProjectId: running?.projectId,
    title: running?.description ?? "",
    start,
    end,
    lastEntryEnd,
  };
}

async function serveFormPage(
  response: ServerResponse,
  formContext: FormContext,
): Promise<void> {
  const html = await readFile(join(distWebDir, "index.html"), "utf8");
  const context = buildFormPageContext(formContext);
  const injected = html.replace(
    "</head>",
    `<script>window.__CLOCKIFY_CONTEXT__ = ${toInlineJson(context)};</script></head>`,
  );
  sendHtml(response, injected);
}

function toInlineJson(value: unknown): string {
  return JSON.stringify(value)
    .replaceAll("<", "\\u003c")
    .replaceAll(">", "\\u003e")
    .replaceAll("&", "\\u0026")
    .replaceAll(" ", "\\u2028")
    .replaceAll(" ", "\\u2029");
}

async function serveStaticFile(
  response: ServerResponse,
  filePath: string,
): Promise<boolean> {
  const resolved = resolvePath(filePath);
  if (resolved !== distWebDir && !resolved.startsWith(`${distWebDir}${sep}`)) {
    return false;
  }
  try {
    const data = await readFile(resolved);
    response.setHeader(
      "content-type",
      staticContentTypes[extname(resolved)] ?? "application/octet-stream",
    );
    response.end(data);
    return true;
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return false;
    }
    throw error;
  }
}

function sendHtml(response: ServerResponse, html: string): void {
  response.setHeader("content-type", "text/html; charset=utf-8");
  response.end(html);
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

async function main(): Promise<void> {
  const parsed = parseArgs(process.argv.slice(2));
  const outputMode: OutputMode = parsed.options.json ? "json" : "text";
  try {
    if (
      parsed.command === "help" ||
      parsed.command === "--help" ||
      hasFlag(parsed.rest, "--help")
    ) {
      printHelp();
      return;
    }
    if (parsed.command === "status") {
      await commandStatus(parsed.options);
    } else if (parsed.command === "projects") {
      await commandProjects(parsed.rest, parsed.options);
    } else if (parsed.command === "start") {
      await commandStart(parsed.rest, parsed.options);
    } else if (parsed.command === "stop") {
      await commandStop(parsed.rest, parsed.options);
    } else if (parsed.command === "add") {
      await commandAdd(parsed.rest, parsed.options);
    } else if (parsed.command === "edit") {
      await commandEdit(parsed.rest, parsed.options);
    } else if (parsed.command === "prompt") {
      await commandPrompt(parsed.options);
    } else if (parsed.command === "form") {
      await commandForm(parsed.rest, parsed.options);
    } else if (parsed.command === "alias") {
      await commandAlias(parsed.rest, parsed.options);
    } else if (parsed.command === "client") {
      await commandClient(parsed.rest, parsed.options);
    } else {
      throw new UserError(`Unknown command: ${parsed.command}`);
    }
  } catch (error) {
    printError(parsed.command, error, outputMode);
    process.exitCode = 1;
    if (outputMode === "text" && error instanceof UserError) {
      console.error("Run `dnb-clockify --help` for usage.");
    }
  }
}

await main();
