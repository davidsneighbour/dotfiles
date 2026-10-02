import { isAbsolute } from "node:path";
import { canonicalRemote } from "./git.ts";
import { validId } from "./importer.ts";
import { optionalRead, record, safePath, strings } from "./vault.ts";

export const CONFIG = ".obsidian/git-commit-reports/config.json";
export const OBSERVATIONS = ".obsidian/git-commit-reports/observations.json";
export interface SyncRepository {
  id: string;
  paths: string[];
  canonical_remote: string | null;
  fetch: "never" | "origin";
  refs: string[];
}
export interface SyncConfig {
  schema_version: 1;
  repositories: SyncRepository[];
}
const defaults = ["refs/heads/", "refs/remotes/origin/"];
export function parseConfig(source: string): SyncConfig {
  const value = record(JSON.parse(source) as unknown);
  if (value["schema_version"] !== 1 || !Array.isArray(value["repositories"]))
    throw new Error(
      "Sync config requires schema_version 1 and repositories list",
    );
  const ids = new Set<string>();
  const paths = new Set<string>();
  const repositories = value["repositories"].map(
    (raw: unknown): SyncRepository => {
      const entry = record(raw);
      const id = entry["id"];
      if (typeof id !== "string" || !validId(id) || ids.has(id))
        throw new Error("Sync config requires unique stable repository IDs");
      ids.add(id);
      const locations = strings(entry["paths"], "paths");
      if (
        !locations.length ||
        locations.some((path) => !isAbsolute(path) || paths.has(path))
      )
        throw new Error("Clone paths must be absolute and configured once");
      for (const path of locations) paths.add(path);
      const remote = entry["canonical_remote"];
      if (
        remote !== null &&
        (typeof remote !== "string" || canonicalRemote(remote) !== remote)
      )
        throw new Error(
          "canonical_remote must be null or a credential-free canonical hosted URL",
        );
      const fetch = entry["fetch"] ?? "never";
      if (fetch !== "never" && fetch !== "origin")
        throw new Error("fetch must be never or origin");
      const refs =
        entry["refs"] === undefined
          ? [...defaults]
          : strings(entry["refs"], "refs");
      if (
        !refs.length ||
        refs.some(
          (ref) =>
            !/^refs\/(?:heads|remotes\/origin|tags)\/(?:[A-Za-z0-9._/-]*)$/.test(
              ref,
            ) ||
            ref.includes("..") ||
            ref.includes("//") ||
            ref.endsWith(".lock"),
        )
      )
        throw new Error(
          "refs must contain full branch, origin, or tag names, or prefixes ending in /",
        );
      return {
        id,
        paths: [...new Set(locations)],
        canonical_remote: remote,
        fetch,
        refs: [...new Set(refs)].sort(),
      };
    },
  );
  return { schema_version: 1, repositories };
}
export async function loadConfig(vault: string): Promise<SyncConfig> {
  const source = await optionalRead(await safePath(vault, CONFIG));
  if (source === undefined)
    throw new Error(
      "Missing sync config; create .obsidian/git-commit-reports/config.json using the documented schema",
    );
  return parseConfig(source);
}
