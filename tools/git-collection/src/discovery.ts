import { lstatSync, readdirSync, readFileSync, realpathSync } from "node:fs";
import { dirname, isAbsolute, relative, resolve, sep } from "node:path";
import { safeError } from "./collector.ts";

export interface DiscoveryConfig {
  roots: string[];
  exclude: string[];
  maxDepth: number;
}

export interface DiscoveryResult {
  repositories: string[];
  errors: { path: string; error: string }[];
}

export function loadConfig(file: string): DiscoveryConfig {
  const value: unknown = JSON.parse(readFileSync(file, "utf8"));
  if (typeof value !== "object" || value === null || Array.isArray(value))
    throw new Error("Discovery config must be an object.");
  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).some(
      (key) => !["roots", "exclude", "maxDepth"].includes(key),
    )
  )
    throw new Error("Unknown discovery config key.");
  const roots = paths(record.roots, "roots");
  const exclude = paths(record.exclude ?? [], "exclude");
  const maxDepth = record.maxDepth ?? 4;
  if (
    !Number.isInteger(maxDepth) ||
    typeof maxDepth !== "number" ||
    maxDepth < 0 ||
    maxDepth > 100
  ) {
    throw new Error("maxDepth must be an integer from 0 to 100.");
  }
  if (!roots.length) throw new Error("Configure at least one discovery root.");
  const base = dirname(resolve(file));
  return {
    roots: roots.map((path) => resolve(base, path)),
    exclude: exclude.map((path) => resolve(base, path)),
    maxDepth,
  };
}

function paths(value: unknown, key: string): string[] {
  if (
    !Array.isArray(value) ||
    !value.every(
      (path: unknown) => typeof path === "string" && path.trim().length > 0,
    )
  ) {
    throw new Error(`${key} must be an array of non-empty paths.`);
  }
  return value as string[];
}

function within(path: string, root: string): boolean {
  const difference = relative(root, path);
  return (
    difference === "" ||
    (difference !== ".." &&
      !difference.startsWith(`..${sep}`) &&
      !isAbsolute(difference))
  );
}

export function inScope(path: string, config: DiscoveryConfig): boolean {
  return (
    !config.exclude.some((excluded) => within(path, excluded)) &&
    config.roots.some((root) => {
      if (!within(path, root)) return false;
      const difference = relative(root, path);
      const parts = difference ? difference.split(sep) : [];
      return (
        parts.length <= config.maxDepth &&
        !parts.some((part) => [".git", "node_modules"].includes(part))
      );
    })
  );
}

export function discover(config: DiscoveryConfig): DiscoveryResult {
  const repositories = new Set<string>();
  const visited = new Map<string, number>();
  const errors: DiscoveryResult["errors"] = [];
  function walk(path: string, remaining: number): void {
    if (config.exclude.some((excluded) => within(path, excluded))) return;
    try {
      const info = lstatSync(path);
      if (info.isSymbolicLink())
        throw new Error(
          "Discovery roots must be real directories. Symlink traversal is disabled.",
        );
      if (!info.isDirectory())
        throw new Error("Discovery root is not a directory.");
      const canonical = realpathSync(path);
      if (canonical !== resolve(path))
        throw new Error(
          "Discovery path traverses a symlink. Use its real directory as the root.",
        );
      if ((visited.get(canonical) ?? -1) >= remaining) return;
      visited.set(canonical, remaining);
      const entries = readdirSync(canonical, { withFileTypes: true });
      const names = new Set(entries.map((entry) => entry.name));
      const bare =
        names.has("HEAD") &&
        names.has("objects") &&
        names.has("refs") &&
        names.has("config");
      if (names.has(".git") || bare) repositories.add(canonical);
      if (!remaining || bare) return;
      for (const entry of entries.sort((a, b) =>
        a.name.localeCompare(b.name),
      )) {
        if (
          entry.isDirectory() &&
          ![".git", "node_modules"].includes(entry.name)
        )
          walk(resolve(canonical, entry.name), remaining - 1);
      }
    } catch (error) {
      errors.push({ path, error: safeError(error) });
    }
  }
  for (const root of config.roots) walk(resolve(root), config.maxDepth);
  return { repositories: [...repositories].sort(), errors };
}
