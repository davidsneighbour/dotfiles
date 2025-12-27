#!/usr/bin/env node
/**
 * Backup and import GNOME custom keyboard shortcuts (Ubuntu 25.10+).
 *
 * TOML format:
 *   version = 1
 *   [[shortcuts]]
 *   title = "..."
 *   accelerator = "<Super>t"
 *   command = "..."
 *   # gsettings_path = "/org/.../custom0/"   (comment, written on export)
 */

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir, userInfo } from "node:os";
import os from "node:os";
import { resolve } from "node:path";

type LogLevel = "INFO" | "WARN" | "ERROR";
type Mode = "merge" | "replace";

interface CliOptions {
  cmd: "backup" | "import" | "list" | "help";
  inFile?: string;
  outFile?: string;
  mode: Mode;
  dryRun: boolean;
  verbose: boolean;
}

interface Shortcut {
  title: string;
  accelerator: string;
  command: string;
  path?: string; // GNOME path (used internally and exported as comment)
}

interface BackupDoc {
  version: number;
  shortcuts: Shortcut[];
  meta?: {
    exportedAtIso: string;
    host: string;
    user: string;
  };
}

const LOG_DIR = resolve(homedir(), ".logs");
const TIMESTAMP = formatTimestamp(new Date());
const LOG_FILE = resolve(LOG_DIR, `setup-log-${TIMESTAMP}.log`);

function main(): void {
  const opts = parseArgs(process.argv.slice(2));

  ensureLogDir();
  if (opts.verbose) log("INFO", `Log file: ${LOG_FILE}`, true);

  if (opts.cmd === "help") {
    printHelp();
    process.exit(0);
  }

  if (!commandExists("gsettings")) {
    log("ERROR", "Missing required command: gsettings", true);
    printHelp();
    process.exit(2);
  }

  try {
    switch (opts.cmd) {
      case "list": {
        const current = readCurrentShortcuts();
        printShortcuts(current);
        break;
      }

      case "backup": {
        const outFile = resolve(opts.outFile ?? "keybindings.toml");

        const meta = {
          exportedAtIso: new Date().toISOString(),
          host: os.hostname(),
          user: safeUserName(),
        };

        const doc: BackupDoc = {
          version: 1,
          shortcuts: readCurrentShortcutsWithPaths().map((s) => ({
            title: s.title,
            accelerator: s.accelerator,
            command: s.command,
            path: s.path,
          })),
          meta,
        };

        const toml = toToml(doc);

        if (opts.dryRun) {
          log("INFO", `[dry-run] Would write ${doc.shortcuts.length} shortcuts to ${outFile}`, true);
        } else {
          writeFileSync(outFile, toml, "utf8");
          log("INFO", `Wrote ${doc.shortcuts.length} shortcuts to ${outFile}`, true);
        }
        break;
      }

      case "import": {
        const inFile = opts.inFile ? resolve(opts.inFile) : undefined;
        if (!inFile) {
          log("ERROR", "Missing --in for import", true);
          printHelp();
          process.exit(2);
        }
        if (!existsSync(inFile)) {
          log("ERROR", `Input file not found: ${inFile}`, true);
          process.exit(2);
        }

        const doc = parseToml(readFileSync(inFile, "utf8"));
        validateDoc(doc);

        const desired = doc.shortcuts;
        const existing = readCurrentShortcutsWithPaths();
        const plan = buildImportPlan(desired, existing, opts.mode);

        if (opts.dryRun) {
          log("INFO", `[dry-run] Planned operations: ${plan.ops.length}`, true);
          for (const op of plan.ops) log("INFO", `[dry-run] ${op}`, true);
          break;
        }

        applyImportPlan(plan, opts.verbose);
        log("INFO", `Import completed. Mode: ${opts.mode}`, true);
        break;
      }

      default: {
        printHelp();
        process.exit(2);
      }
    }
  } catch (err: unknown) {
    log("ERROR", formatUnknownError(err), true);
    process.exit(1);
  }
}

/**
 * Parse CLI arguments.
 *
 * @param argv Command line arguments (excluding node + script path)
 * @returns Parsed options
 */
function parseArgs(argv: string[]): CliOptions {
  const opts: CliOptions = {
    cmd: "help",
    mode: "merge",
    dryRun: false,
    verbose: false,
  };

    if (argv.length === 0) {
    opts.cmd = "help";
    return opts;
    }

  const [first, ...rest] = argv;
  if (first === "backup" || first === "import" || first === "list" || first === "help") {
    opts.cmd = first;
  } else {
    opts.cmd = "help";
    return opts;
  }

  const args = [...rest];
  while (args.length > 0) {
    const a = args.shift();
    if (!a) break;

    switch (a) {
      case "--help":
        opts.cmd = "help";
        return opts;
      case "--verbose":
        opts.verbose = true;
        break;
      case "--dry-run":
        opts.dryRun = true;
        break;
      case "--in": {
        const v = args.shift();
        if (!v) throw new Error("Missing value for --in");
        opts.inFile = v;
        break;
      }
      case "--out": {
        const v = args.shift();
        if (!v) throw new Error("Missing value for --out");
        opts.outFile = v;
        break;
      }
      case "--mode": {
        const v = args.shift();
        if (!v) throw new Error("Missing value for --mode");
        if (v !== "merge" && v !== "replace") throw new Error(`Invalid --mode: ${v}`);
        opts.mode = v;
        break;
      }
      default:
        throw new Error(`Unknown argument: ${a}`);
    }
  }

  return opts;
}

function printHelp(): void {
  const text = `
Usage:
  node keybinds.ts list [--verbose]
  node keybinds.ts backup [--out <file>] [--dry-run] [--verbose]
  node keybinds.ts import --in <file> [--mode <merge|replace>] [--dry-run] [--verbose]
  node keybinds.ts --help

Description:
  Backup and restore GNOME custom keyboard shortcuts on Ubuntu 25.10+.
  Shortcuts are exported to and imported from a human-readable TOML file.

Commands:
  list        Show currently configured custom shortcuts
  backup      Export shortcuts to a TOML file
  import      Import shortcuts from a TOML file
  help        Show this help output

Options:
  --in        Input TOML file (required for import)
  --out       Output TOML file (default: ./keybindings.toml)
  --mode      merge (default): update/create by exact title match
              replace: remove all existing custom shortcuts first
  --dry-run   Show planned changes without applying them
  --verbose   Print detailed output and write logs to ~/.logs

Notes:
  * Shortcut matching during import is exact on 'title'
  * TOML exports include helpful comments and original gsettings paths
`.trim();

  process.stdout.write(text + "\n");
}


function ensureLogDir(): void {
  if (!existsSync(LOG_DIR)) mkdirSync(LOG_DIR, { recursive: true });
}

function log(level: LogLevel, message: string, alsoStdout: boolean): void {
  const line = `[${new Date().toISOString()}] [${level}] ${message}\n`;
  try {
    writeFileSync(LOG_FILE, line, { encoding: "utf8", flag: "a" });
  } catch {
    // continue
  }
  if (alsoStdout) process.stdout.write(line);
}

function formatTimestamp(d: Date): string {
  const pad = (n: number): string => String(n).padStart(2, "0");
  const y = d.getFullYear();
  const m = pad(d.getMonth() + 1);
  const day = pad(d.getDate());
  const hh = pad(d.getHours());
  const mm = pad(d.getMinutes());
  const ss = pad(d.getSeconds());
  return `${y}${m}${day}-${hh}${mm}${ss}`;
}

function formatUnknownError(err: unknown): string {
  if (err instanceof Error) return `${err.name}: ${err.message}\n${err.stack ?? ""}`.trim();
  return `Unknown error: ${String(err)}`;
}

function commandExists(cmd: string): boolean {
  const r = spawnSync("bash", ["-lc", `command -v ${escapeShell(cmd)} >/dev/null 2>&1`], {
    encoding: "utf8",
  });
  return r.status === 0;
}

function escapeShell(s: string): string {
  return s.replaceAll(/'/g, `'\\''`);
}

function safeUserName(): string {
  try {
    return userInfo().username || "unknown";
  } catch {
    return "unknown";
  }
}

/**
 * Read the list of GNOME custom-keybindings paths.
 */
function getCustomKeybindingPaths(): string[] {
  const out = gsettingsGet("org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings");
  return parseGsettingsStrv(out);
}

function readCurrentShortcuts(): Shortcut[] {
  return readCurrentShortcutsWithPaths().map(({ path: _p, ...rest }) => rest);
}

function readCurrentShortcutsWithPaths(): Required<Shortcut>[] {
  const paths = getCustomKeybindingPaths();
  const shortcuts: Required<Shortcut>[] = [];

  for (const path of paths) {
    const title = parseGsettingsString(gsettingsGetReloc(path, "name"));
    const command = parseGsettingsString(gsettingsGetReloc(path, "command"));
    const accelerator = parseGsettingsString(gsettingsGetReloc(path, "binding"));

    shortcuts.push({ title, command, accelerator, path });
  }

  shortcuts.sort((a, b) => a.title.localeCompare(b.title));
  return shortcuts;
}

function printShortcuts(shortcuts: Shortcut[]): void {
  if (shortcuts.length === 0) {
    process.stdout.write("No custom shortcuts found.\n");
    return;
  }
  for (const s of shortcuts) {
    process.stdout.write(`- ${s.title}\n`);
    process.stdout.write(`  accelerator: ${s.accelerator}\n`);
    process.stdout.write(`  command: ${s.command}\n`);
  }
}

function gsettingsGet(schema: string, key: string): string {
  const r = spawnSync("gsettings", ["get", schema, key], { encoding: "utf8" });
  if (r.status !== 0) {
    const stderr = (r.stderr ?? "").trim();
    throw new Error(`gsettings get failed (${schema} ${key}): ${stderr || "unknown error"}`);
  }
  return (r.stdout ?? "").trim();
}

function gsettingsGetReloc(path: string, key: string): string {
  const schemaWithPath = `org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:` + path;
  const r = spawnSync("gsettings", ["get", schemaWithPath, key], { encoding: "utf8" });
  if (r.status !== 0) {
    const stderr = (r.stderr ?? "").trim();
    throw new Error(`gsettings get failed (${schemaWithPath} ${key}): ${stderr || "unknown error"}`);
  }
  return (r.stdout ?? "").trim();
}

function gsettingsSet(schema: string, key: string, value: string, verbose: boolean): void {
  if (verbose) log("INFO", `gsettings set ${schema} ${key} ${value}`, true);
  const r = spawnSync("gsettings", ["set", schema, key, value], { encoding: "utf8" });
  if (r.status !== 0) {
    const stderr = (r.stderr ?? "").trim();
    throw new Error(`gsettings set failed (${schema} ${key}): ${stderr || "unknown error"}`);
  }
}

function gsettingsSetReloc(path: string, key: string, value: string, verbose: boolean): void {
  const schemaWithPath = `org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:` + path;
  if (verbose) log("INFO", `gsettings set ${schemaWithPath} ${key} ${value}`, true);
  const r = spawnSync("gsettings", ["set", schemaWithPath, key, value], { encoding: "utf8" });
  if (r.status !== 0) {
    const stderr = (r.stderr ?? "").trim();
    throw new Error(`gsettings set failed (${schemaWithPath} ${key}): ${stderr || "unknown error"}`);
  }
}

/**
 * Parse gsettings string output (single-quoted, with escapes).
 * Example: "'Launch Calculator'"
 */
function parseGsettingsString(s: string): string {
  const t = s.trim();
  if (t.startsWith("'") && t.endsWith("'") && t.length >= 2) {
    const inner = t.slice(1, -1);
    return inner.replaceAll("\\'", "'").replaceAll("\\\\", "\\");
  }
  return t;
}

/**
 * Parse gsettings strv output (array of single-quoted strings).
 * Example: "['/path1/', '/path2/']"
 */
function parseGsettingsStrv(s: string): string[] {
  const t = s.trim();
  if (t === "@" || t === "[]") return [];
  if (!t.startsWith("[") || !t.endsWith("]")) return [];
  const inner = t.slice(1, -1).trim();
  if (inner === "") return [];

  const parts = inner
    .split(",")
    .map((p) => p.trim())
    .filter(Boolean);

  return parts.map(parseGsettingsString);
}

/**
 * TOML writer with comments for export metadata and each gsettings_path.
 */
function toToml(doc: BackupDoc): string {
  const lines: string[] = [];

  lines.push("# GNOME custom keyboard shortcuts export");
  if (doc.meta) {
    lines.push(`# exported_at = ${tomlString(doc.meta.exportedAtIso)}`);
    lines.push(`# host = ${tomlString(doc.meta.host)}`);
    lines.push(`# user = ${tomlString(doc.meta.user)}`);
  }
  lines.push(`version = ${doc.version}`);
  lines.push("");

  const shortcuts = [...doc.shortcuts].sort((a, b) => a.title.localeCompare(b.title));
  for (const s of shortcuts) {
    lines.push("[[shortcuts]]");
    lines.push(`title = ${tomlString(s.title)}`);
    lines.push(`accelerator = ${tomlString(s.accelerator)}`);
    lines.push(`command = ${tomlString(s.command)}`);
    if (s.path) lines.push(`# gsettings_path = ${tomlString(s.path)}`);
    lines.push("");
  }

  return lines.join("\n").trimEnd() + "\n";
}

function tomlString(s: string): string {
  const escaped = s.replaceAll("\\", "\\\\").replaceAll('"', '\\"').replaceAll("\n", "\\n");
  return `"${escaped}"`;
}

/**
 * Minimal TOML parser for:
 * version = 1
 * [[shortcuts]]
 * title = "..."
 * accelerator = "..."
 * command = "..."
 *
 * Ignores comment lines, including exported metadata comments.
 */
function parseToml(input: string): BackupDoc {
  const lines = input.split(/\r?\n/);

  let version: number | undefined;
  const shortcuts: Shortcut[] = [];

  let current: Partial<Shortcut> | null = null;

  for (let i = 0; i < lines.length; i += 1) {
    const raw = lines[i] ?? "";
    const line = raw.trim();

    if (line === "" || line.startsWith("#")) continue;

    if (line === "[[shortcuts]]") {
      if (current) shortcuts.push(finaliseShortcut(current, i + 1));
      current = {};
      continue;
    }

    const m = line.match(/^([A-Za-z0-9_-]+)\s*=\s*(.+)$/);
    if (!m) {
      throw new Error(`TOML parse error on line ${i + 1}: ${raw}`);
    }
    const key = m[1] ?? "";
    const valueRaw = (m[2] ?? "").trim();

    if (key === "version") {
      const n = Number(valueRaw);
      if (!Number.isInteger(n) || n <= 0) throw new Error(`Invalid version on line ${i + 1}`);
      version = n;
      continue;
    }

    if (!current) {
      throw new Error(`Unexpected key before [[shortcuts]] on line ${i + 1}: ${key}`);
    }

    if (key === "title" || key === "accelerator" || key === "command") {
      current[key] = parseTomlString(valueRaw, i + 1);
      continue;
    }

    throw new Error(`Unknown key on line ${i + 1}: ${key}`);
  }

  if (current) shortcuts.push(finaliseShortcut(current, lines.length));

  return { version: version ?? 1, shortcuts };
}

function parseTomlString(v: string, lineNo: number): string {
  const t = v.trim();
  if (!t.startsWith('"') || !t.endsWith('"') || t.length < 2) {
    throw new Error(`Expected double-quoted string on line ${lineNo}`);
  }
  const inner = t.slice(1, -1);
  return inner
    .replaceAll('\\"', '"')
    .replaceAll("\\n", "\n")
    .replaceAll("\\\\", "\\");
}

function finaliseShortcut(s: Partial<Shortcut>, lineNo: number): Shortcut {
  const title = (s.title ?? "");
  const accelerator = (s.accelerator ?? "");
  const command = (s.command ?? "");

  if (!title || !accelerator || !command) {
    throw new Error(
      `Incomplete [[shortcuts]] entry (missing title/accelerator/command) near line ${lineNo}`
    );
  }

  return { title, accelerator, command };
}

function validateDoc(doc: BackupDoc): void {
  if (!Number.isInteger(doc.version) || doc.version <= 0) {
    throw new Error(`Invalid doc version: ${doc.version}`);
  }
  if (!Array.isArray(doc.shortcuts)) throw new Error("Invalid shortcuts list");

  // Exact-match identity: titles must be unique as written.
  const seen = new Set<string>();
  for (const s of doc.shortcuts) {
    if (seen.has(s.title)) throw new Error(`Duplicate shortcut title in TOML: ${s.title}`);
    seen.add(s.title);
  }
}

type ImportPlan = {
  ops: string[];
  finalPaths: string[];
  toWrite: Array<{ path: string; shortcut: Shortcut }>;
};

function buildImportPlan(
  desired: Shortcut[],
  existing: Required<Shortcut>[],
  mode: Mode
): ImportPlan {
  const ops: string[] = [];
  const toWrite: Array<{ path: string; shortcut: Shortcut }> = [];

  const existingByTitleExact = new Map<string, Required<Shortcut>>();
  for (const e of existing) existingByTitleExact.set(e.title, e);

  let paths: string[] = mode === "replace" ? [] : existing.map((e) => e.path);

  const usedNumbers = new Set<number>();
  for (const p of paths) {
    const n = extractCustomIndex(p);
    if (n !== null) usedNumbers.add(n);
  }

  const nextIndex = (): number => {
    let i = 0;
    while (usedNumbers.has(i)) i += 1;
    usedNumbers.add(i);
    return i;
  };

  for (const d of desired) {
    const match = existingByTitleExact.get(d.title);

    if (match && mode === "merge") {
      ops.push(`Update: "${d.title}" at ${match.path}`);
      toWrite.push({ path: match.path, shortcut: d });
      continue;
    }

    const i = nextIndex();
    const path = `/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom${i}/`;
    ops.push(`Create: "${d.title}" at ${path}`);
    toWrite.push({ path, shortcut: d });

    if (!paths.includes(path)) paths.push(path);
  }

  if (mode === "replace") {
    paths = [];
    for (const w of toWrite) {
      if (!paths.includes(w.path)) paths.push(w.path);
    }
  }

  paths.sort((a, b) => {
    const ai = extractCustomIndex(a);
    const bi = extractCustomIndex(b);
    if (ai !== null && bi !== null) return ai - bi;
    return a.localeCompare(b);
  });

  return { ops, finalPaths: paths, toWrite };
}

function extractCustomIndex(path: string): number | null {
  const m = path.match(/\/custom-keybindings\/custom(\d+)\//);
  if (!m) return null;
  const n = Number(m[1]);
  return Number.isInteger(n) ? n : null;
}

function applyImportPlan(plan: ImportPlan, verbose: boolean): void {
  const strvValue = toGsettingsStrv(plan.finalPaths);
  gsettingsSet(
    "org.gnome.settings-daemon.plugins.media-keys",
    "custom-keybindings",
    strvValue,
    verbose
  );

  for (const w of plan.toWrite) {
    gsettingsSetReloc(w.path, "name", toGsettingsString(w.shortcut.title), verbose);
    gsettingsSetReloc(w.path, "command", toGsettingsString(w.shortcut.command), verbose);
    gsettingsSetReloc(w.path, "binding", toGsettingsString(w.shortcut.accelerator), verbose);
  }
}

function toGsettingsString(s: string): string {
  const escaped = s.replaceAll("\\", "\\\\").replaceAll("'", "\\'");
  return `'${escaped}'`;
}

function toGsettingsStrv(values: string[]): string {
  const parts = values.map((v) => toGsettingsString(v));
  return `[${parts.join(", ")}]`;
}

main();
