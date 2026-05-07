#!/usr/bin/env node

/**
 * Kando "Workspace Starter" menu updater.
 *
 * Updates a target menu's root.children based on *.code-workspace files in a directory.
 *
 * Usage:
 *   node ${SELF} --help
 *   node ${SELF} --dry-run
 *   node ${SELF} --apply
 *
 * Notes:
 * - Creates a timestamped backup next to the original menu.json before writing.
 * - Replaces root.children entirely (does not merge).
 */

import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import process from "node:process";

const DEFAULTS = {
  menuJsonPath: path.join(
    os.homedir(),
    ".config/kando/menus.json",
  ),
  workspacesDir:
    "/home/patrick/github.com/davidsneighbour/dotfiles/configs/workspaces",
  menuName: "Workspace Starter",
  vscodeCommand: "/usr/share/code/code",
  icon: "code",
  iconTheme: "material-symbols-rounded",
  includeExtensions: [".code-workspace"],
};

function printHelp() {
  const cmd = path.basename(process.argv[1] ?? "kando-workspaces.mjs");
  console.log(`
${cmd} - update Kando "Workspace Starter" entries from VS Code workspace files

Usage:
  node ${cmd} --dry-run
  node ${cmd} --apply

Options:
  --menu-json-path <path>     Path to Kando menu.json
                              Default: ${DEFAULTS.menuJsonPath}

  --workspaces-dir <path>     Directory containing workspace files
                              Default: ${DEFAULTS.workspacesDir}

  --menu-name <name>          Kando menu root.name to update
                              Default: ${DEFAULTS.menuName}

  --vscode-command <command>  Command used in each entry
                              Default: ${DEFAULTS.vscodeCommand}

  --extensions <list>         Comma-separated list of file extensions to include
                              Default: ${DEFAULTS.includeExtensions.join(",")}

  --dry-run                   Print what would change; do not write
  --apply                     Write changes (creates backup first)

  --verbose                   Extra logging
  --help                      Show this help

Examples:
  node ${cmd} --dry-run --verbose
  node ${cmd} --apply
  node ${cmd} --apply --menu-name "Workspace Starter" --workspaces-dir "/some/dir"
`.trim());
}

/**
 * @param {string} input
 * @returns {string}
 */
function expandHome(input) {
  if (input === "~") return os.homedir();
  if (input.startsWith("~/")) return path.join(os.homedir(), input.slice(2));
  return input;
}

/**
 * @param {string} s
 * @returns {string}
 */
function safeJsonPreview(s) {
  return s.length > 2000 ? `${s.slice(0, 2000)}\n... (truncated)` : s;
}

/**
 * @param {string} value
 * @returns {string[]}
 */
function parseCommaList(value) {
  return value
    .split(",")
    .map((x) => x.trim())
    .filter(Boolean);
}

/**
 * Minimal CLI parser (no dependencies).
 * @param {string[]} argv
 */
function parseArgs(argv) {
  /** @type {Record<string, string | boolean>} */
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (!a) continue;

    if (a === "--help") out.help = true;
    else if (a === "--verbose") out.verbose = true;
    else if (a === "--dry-run") out.dryRun = true;
    else if (a === "--apply") out.apply = true;
    else if (a === "--menu-json-path") out.menuJsonPath = argv[++i] ?? "";
    else if (a === "--workspaces-dir") out.workspacesDir = argv[++i] ?? "";
    else if (a === "--menu-name") out.menuName = argv[++i] ?? "";
    else if (a === "--vscode-command") out.vscodeCommand = argv[++i] ?? "";
    else if (a === "--extensions") out.extensions = argv[++i] ?? "";
    else {
      throw new Error(`Unknown argument: ${a}`);
    }
  }
  return out;
}

/**
 * @param {boolean} verbose
 * @param {...unknown} args
 */
function vlog(verbose, ...args) {
  if (verbose) console.log(...args);
}

/**
 * @param {string} filePath
 */
async function pathExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch (e) {
    return false;
  }
}

/**
 * @param {string} menuJsonPath
 * @param {boolean} verbose
 */
async function readMenuJson(menuJsonPath, verbose) {
  vlog(verbose, `Reading: ${menuJsonPath}`);
  const raw = await fs.readFile(menuJsonPath, "utf8");
  try {
    return { raw, json: JSON.parse(raw) };
  } catch (e) {
    console.error("Failed to parse JSON from menu.json.");
    console.error("First part of file for debugging:");
    console.error(safeJsonPreview(raw));
    throw e;
  }
}

/**
 * @param {string} workspacesDir
 * @param {string[]} includeExtensions
 * @param {boolean} verbose
 */
async function listWorkspaceFiles(workspacesDir, includeExtensions, verbose) {
  const dir = workspacesDir;
  const stat = await fs.stat(dir);
  if (!stat.isDirectory()) {
    throw new Error(`workspaces dir is not a directory: ${dir}`);
  }

  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = entries
    .filter((d) => d.isFile())
    .map((d) => d.name)
    .filter((name) =>
      includeExtensions.some((ext) => name.toLowerCase().endsWith(ext)),
    )
    .sort((a, b) => a.localeCompare(b, "en"));

  vlog(verbose, `Found ${files.length} workspace file(s) in ${dir}`);
  return files.map((name) => path.join(dir, name));
}

/**
 * @param {string} vscodeCommand
 * @param {string} workspaceFilePath
 * @param {string} name
 * @param {string} icon
 * @param {string} iconTheme
 */
function makeChildEntry(
  vscodeCommand,
  workspaceFilePath,
  name,
  icon,
  iconTheme,
) {
  return {
    type: "command",
    data: {
      command: `${vscodeCommand} ${workspaceFilePath}`,
      detached: true,
      isolated: false,
      delayed: false,
    },
    name,
    icon,
    iconTheme,
  };
}

/**
 * @param {unknown} root
 * @returns {root is { type?: unknown, name?: unknown, children?: unknown[] }}
 */
function isMenuRootObject(root) {
  return typeof root === "object" && root !== null;
}

/**
 * @param {unknown} menu
 * @returns {menu is { root?: unknown }}
 */
function isMenuObject(menu) {
  return typeof menu === "object" && menu !== null;
}

/**
 * Replace root.children in the target menu.
 * @param {any} configJson
 * @param {string} menuName
 * @param {any[]} children
 * @param {boolean} verbose
 */
function updateTargetMenu(configJson, menuName, children, verbose) {
  if (typeof configJson !== "object" || configJson === null) {
    throw new Error("menu.json root is not an object");
  }
  const menus = /** @type {any} */ (configJson).menus;
  if (!Array.isArray(menus)) {
    throw new Error('menu.json is missing a top-level "menus" array');
  }

  /** @type {number[]} */
  const matches = [];

  for (let i = 0; i < menus.length; i += 1) {
    const m = menus[i];
    if (!isMenuObject(m)) continue;
    const root = m.root;
    if (!isMenuRootObject(root)) continue;

    const rootName = root.name;
    const rootType = root.type;

    if (rootType === "submenu" && rootName === menuName) {
      matches.push(i);
    }
  }

  if (matches.length === 0) {
    throw new Error(`No menu found with root.type="submenu" and root.name="${menuName}"`);
  }
  if (matches.length > 1) {
    throw new Error(
      `Multiple menus found with root.name="${menuName}". Refine the selector (e.g. rename the menu or adjust the script). Matches at indices: ${matches.join(
        ", ",
      )}`,
    );
  }

  const idx = matches[0];
  vlog(verbose, `Updating menus[${idx}].root.children for "${menuName}"`);

  const target = menus[idx];
  target.root.children = children;

  return { updatedIndex: idx };
}

/**
 * @param {string} menuJsonPath
 * @param {string} originalRaw
 * @param {boolean} verbose
 */
async function writeBackup(menuJsonPath, originalRaw, verbose) {
  const ts = new Date()
    .toISOString()
    .replaceAll(":", "")
    .replaceAll("-", "")
    .replaceAll(".", "");
  const backupPath = `${menuJsonPath}.bak-${ts}`;
  vlog(verbose, `Writing backup: ${backupPath}`);
  await fs.writeFile(backupPath, originalRaw, "utf8");
  return backupPath;
}

/**
 * @param {string} menuJsonPath
 * @param {any} updatedJson
 * @param {boolean} verbose
 */
async function writeUpdatedMenu(menuJsonPath, updatedJson, verbose) {
  const out = JSON.stringify(updatedJson, null, 2) + "\n";
  vlog(verbose, `Writing updated file: ${menuJsonPath}`);
  await fs.writeFile(menuJsonPath, out, "utf8");
}

/**
 * @param {any[]} beforeChildren
 * @param {any[]} afterChildren
 */
function summariseChange(beforeChildren, afterChildren) {
  return {
    beforeCount: Array.isArray(beforeChildren) ? beforeChildren.length : 0,
    afterCount: afterChildren.length,
    beforeNames: (Array.isArray(beforeChildren) ? beforeChildren : [])
      .map((c) => (typeof c?.name === "string" ? c.name : null))
      .filter(Boolean),
    afterNames: afterChildren
      .map((c) => (typeof c?.name === "string" ? c.name : null))
      .filter(Boolean),
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help) {
    printHelp();
    process.exit(0);
  }

  const verbose = Boolean(args.verbose);

  const apply = Boolean(args.apply);
  const dryRun = Boolean(args.dryRun);

  if (!apply && !dryRun) {
    printHelp();
    console.error("\nError: you must pass either --dry-run or --apply.");
    process.exit(2);
  }

  const menuJsonPath = expandHome(
    typeof args.menuJsonPath === "string" && args.menuJsonPath.length > 0
      ? args.menuJsonPath
      : DEFAULTS.menuJsonPath,
  );

  const workspacesDir = expandHome(
    typeof args.workspacesDir === "string" && args.workspacesDir.length > 0
      ? args.workspacesDir
      : DEFAULTS.workspacesDir,
  );

  const menuName =
    typeof args.menuName === "string" && args.menuName.length > 0
      ? args.menuName
      : DEFAULTS.menuName;

  const vscodeCommand =
    typeof args.vscodeCommand === "string" && args.vscodeCommand.length > 0
      ? args.vscodeCommand
      : DEFAULTS.vscodeCommand;

  const includeExtensions =
    typeof args.extensions === "string" && args.extensions.length > 0
      ? parseCommaList(args.extensions).map((e) => (e.startsWith(".") ? e : `.${e}`))
      : DEFAULTS.includeExtensions;

  if (!(await pathExists(menuJsonPath))) {
    throw new Error(`menu.json not found: ${menuJsonPath}`);
  }
  if (!(await pathExists(workspacesDir))) {
    throw new Error(`workspaces dir not found: ${workspacesDir}`);
  }

  const { raw, json } = await readMenuJson(menuJsonPath, verbose);

  // Prepare children list from workspace files.
  const workspaceFiles = await listWorkspaceFiles(
    workspacesDir,
    includeExtensions,
    verbose,
  );

  const children = workspaceFiles.map((fullPath) => {
    const base = path.basename(fullPath);
    const name = base.replace(/\.[^.]+$/, ""); // strip last extension
    return makeChildEntry(
      vscodeCommand,
      fullPath,
      name,
      DEFAULTS.icon,
      DEFAULTS.iconTheme,
    );
  });

  // Capture existing children for reporting
  let beforeChildren = [];
  {
    const menus = json?.menus;
    if (Array.isArray(menus)) {
      const target = menus.find(
        (m) => m?.root?.type === "submenu" && m?.root?.name === menuName,
      );
      if (target?.root?.children) beforeChildren = target.root.children;
    }
  }

  const change = summariseChange(beforeChildren, children);

  // Apply in-memory update
  updateTargetMenu(json, menuName, children, verbose);

  console.log(
    `Menu "${menuName}": children ${change.beforeCount} -> ${change.afterCount}`,
  );
  if (verbose) {
    console.log("New entries:", change.afterNames);
  }

  if (dryRun) {
    console.log("\n--dry-run: not writing any files.");
    process.exit(0);
  }

  // --apply
  const backupPath = await writeBackup(menuJsonPath, raw, verbose);
  await writeUpdatedMenu(menuJsonPath, json, verbose);

  console.log(`\nApplied changes.`);
  console.log(`Backup created: ${backupPath}`);
  console.log(`Updated: ${menuJsonPath}`);
}

main().catch((e) => {
  console.error("\nFatal error:");
  console.error(e instanceof Error ? e.stack ?? e.message : String(e));
  process.exit(1);
});
