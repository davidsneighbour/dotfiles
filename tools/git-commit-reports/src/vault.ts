import { createHash, randomUUID } from "node:crypto";
import { constants } from "node:fs";
import {
  lstat,
  mkdir,
  open,
  readdir,
  readFile,
  rename,
  rmdir,
  unlink,
} from "node:fs/promises";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { Document, isMap, parseDocument } from "yaml";

export const ARCHIVE = "23 Eventlog/Github";
export const STATE = ".obsidian/git-commit-reports/repositories.json";
export interface Note {
  source: string;
  properties: Record<string, unknown>;
  body: string;
  document: Document;
}
export function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new Error("Expected a property mapping");
  return value as Record<string, unknown>;
}
export function strings(value: unknown, field: string): string[] {
  if (
    !Array.isArray(value) ||
    !value.every((entry) => typeof entry === "string")
  )
    throw new Error(`Invalid ${field}: expected a string list`);
  return value as string[];
}
export function parseNote(source: string): Note {
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n/.exec(source);
  if (!match) throw new Error("Note requires YAML frontmatter");
  const document = parseDocument(match[1] ?? "", { uniqueKeys: true });
  if (
    document.errors.length ||
    document.warnings.length ||
    !isMap(document.contents)
  )
    throw new Error("Invalid or unsupported note YAML");
  return {
    source,
    document,
    properties: record(document.toJS({ maxAliasCount: 100 }) as unknown),
    body: source.slice(match[0].length),
  };
}
export const digest = (body: string): string =>
  createHash("sha256").update(body).digest("hex");
export const sorted = (values: string[]): string[] =>
  [...new Set(values)].sort();
export function serialise(
  properties: Record<string, unknown>,
  body: string,
  existing?: Note,
): string {
  const document = existing?.document.clone() ?? new Document();
  for (const [key, value] of Object.entries(properties))
    document.set(key, value);
  // Obsidian Linter must not rewrite exact Git bodies or generated timestamps.
  if (
    typeof properties["type"] === "string" &&
    properties["type"].startsWith("git-")
  )
    document.set("disabled rules", ["all"]);
  return `---\n${document.toString({ lineWidth: 0 })}---\n${body}`;
}
export async function optionalRead(path: string): Promise<string | undefined> {
  try {
    return await readFile(path, "utf8");
  } catch (error) {
    if (isMissing(error)) return undefined;
    throw error;
  }
}
function isMissing(error: unknown): boolean {
  return (error as NodeJS.ErrnoException).code === "ENOENT";
}

// Reject symlinks in the complete path, including the vault and its ancestors.
export async function safePath(root: string, path: string): Promise<string> {
  const absoluteRoot = resolve(root);
  const absolute = resolve(absoluteRoot, path);
  const rel = relative(absoluteRoot, absolute);
  if (isAbsolute(rel) || rel === ".." || rel.startsWith(`..${sep}`))
    throw new Error("Path escapes the vault");
  const parts = absolute.split(sep).filter(Boolean);
  let current: string = sep;
  for (const [index, part] of parts.entries()) {
    current = join(current, part);
    try {
      const stat = await lstat(current);
      if (stat.isSymbolicLink())
        throw new Error("Symlinks are not allowed in archive paths");
      if (index < parts.length - 1 && !stat.isDirectory())
        throw new Error("Archive parent is not a directory");
    } catch (error) {
      if (isMissing(error)) break;
      throw error;
    }
  }
  return absolute;
}
export async function notes(
  root: string,
  directory: string,
  overlay?: Map<string, string>,
): Promise<Map<string, Note>> {
  const found = new Map<string, Note>();
  async function visit(path: string): Promise<void> {
    const absolute = await safePath(root, path);
    let entries;
    try {
      entries = await readdir(absolute, { withFileTypes: true });
    } catch (error) {
      if (isMissing(error)) return;
      throw error;
    }
    for (const entry of entries) {
      const child = join(path, entry.name);
      if (entry.isSymbolicLink())
        throw new Error("Symlink found inside archive");
      if (entry.isDirectory()) await visit(child);
      else if (entry.isFile() && entry.name.endsWith(".md")) {
        try {
          found.set(
            child,
            parseNote(await readFile(await safePath(root, child), "utf8")),
          );
        } catch {
          throw new Error(`Cannot parse archive note: ${child}`);
        }
      }
    }
  }
  await visit(directory);
  for (const [path, content] of overlay ?? [])
    if (path.startsWith(`${directory}/`) && path.endsWith(".md"))
      found.set(path, parseNote(content));
  return found;
}
export async function atomicWrite(
  root: string,
  path: string,
  content: string,
): Promise<boolean> {
  const absolute = await safePath(root, path);
  if ((await optionalRead(absolute)) === content) return false;
  await mkdir(dirname(absolute), { recursive: true });
  await safePath(root, path);
  const temporary = `${absolute}.${randomUUID()}.tmp`;
  const handle = await open(
    temporary,
    constants.O_CREAT |
      constants.O_EXCL |
      constants.O_WRONLY |
      constants.O_NOFOLLOW,
    0o600,
  );
  try {
    await handle.writeFile(content, "utf8");
    await handle.sync();
  } finally {
    await handle.close();
  }
  try {
    await safePath(root, path);
    await rename(temporary, absolute);
    const directory = await open(dirname(absolute), constants.O_RDONLY);
    try {
      await directory.sync();
    } finally {
      await directory.close();
    }
  } finally {
    try {
      await unlink(temporary);
    } catch (error) {
      if (!isMissing(error))
        console.error(
          "Cannot remove temporary archive file; inspect leftover .tmp files before retrying",
        );
    }
  }
  return true;
}
export async function withLock<T>(
  root: string,
  action: () => Promise<T>,
): Promise<T> {
  const lock = await safePath(root, ".git-commit-reports.lock");
  try {
    await mkdir(lock);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "EEXIST")
      throw new Error(
        "Vault is locked; wait for the other importer. After a crash, verify no writer runs before removing .git-commit-reports.lock",
      );
    throw error;
  }
  try {
    return await action();
  } finally {
    await rmdir(lock);
  }
}
