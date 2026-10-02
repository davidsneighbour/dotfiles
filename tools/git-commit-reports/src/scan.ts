import { existsSync } from "node:fs";
import { join } from "node:path";
import type { SyncRepository } from "./config.ts";
import { git, readAvailableCommits, repositoryInfo } from "./git.ts";
import { type CommitObject, commitIdentity } from "./model.ts";

export type RefTips = Record<string, string>;
const text = (repo: string, args: string[]): string =>
  git(repo, args).toString("utf8").trim();
export function ensureCompleteHistory(
  repo: string,
): ReturnType<typeof repositoryInfo> {
  const info = repositoryInfo(repo);
  if (text(repo, ["rev-parse", "--is-shallow-repository"]) !== "false")
    throw new Error(
      "Shallow history cannot establish absence; use a complete clone",
    );
  if (existsSync(join(info.common, "info/grafts")))
    throw new Error(
      "Git grafts prevent a complete object-history observation; use a clone without grafts",
    );
  return info;
}
export function captureRefs(repo: string, configured: string[]): RefTips {
  const tips: RefTips = {};
  const lines = text(repo, [
    "for-each-ref",
    "--sort=refname",
    "--format=%(refname) %(objectname) %(symref)",
    "refs/heads/",
    "refs/remotes/origin/",
    "refs/tags/",
  ]);
  for (const line of lines.split("\n").filter(Boolean)) {
    const [ref, hash, symbolic] = line.split(" ");
    if (!ref || !hash || symbolic) continue;
    if (
      ref.startsWith("refs/tags/") ||
      configured.some((filter) =>
        filter.endsWith("/") ? ref.startsWith(filter) : ref === filter,
      )
    )
      tips[ref] = hash;
  }
  return tips;
}
export function sameRefs(left: RefTips, right: RefTips): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}
export function scanObjects(
  repo: string,
  info: ReturnType<typeof repositoryInfo>,
  tips: RefTips,
): CommitObject[] {
  const roots: string[] = [];
  for (const [ref, hash] of Object.entries(tips)) {
    commitIdentity(info.format, hash);
    const peeled = text(repo, [
      "rev-parse",
      "--verify",
      "--end-of-options",
      `${hash}^{}`,
    ]);
    const type = text(repo, ["cat-file", "-t", peeled]);
    if (type !== "commit") {
      if (ref.startsWith("refs/tags/")) continue;
      throw new Error("Monitored branch does not point to a commit object");
    }
    roots.push(peeled);
  }
  if (!roots.length) return [];
  const hashes = git(repo, ["rev-list", "--topo-order", "--stdin"], {
    input: `${[...new Set(roots)].join("\n")}\n`,
  })
    .toString("utf8")
    .trim()
    .split("\n")
    .filter(Boolean);
  const available = readAvailableCommits(repo, hashes, info.format);
  if (available.size !== hashes.length)
    throw new Error("Missing commit objects; prior observations are preserved");
  const objects = hashes.map((hash) => {
    const object = available.get(hash);
    if (!object) throw new Error("Missing scanned commit object");
    return object;
  });
  const present = new Set(hashes);
  if (
    objects.some((object) =>
      object.parents.some((parent) => !present.has(parent)),
    )
  )
    throw new Error(
      "Incomplete parent closure; prior observations are preserved",
    );
  return objects;
}
export function fetchOrigin(repo: string, config: SyncRepository): void {
  if (config.fetch === "never") return;
  // Only the branch-to-origin namespace is fetched/pruned. Local branches and tags are untouched.
  git(repo, [
    "fetch",
    "--atomic",
    "--prune",
    "--no-prune-tags",
    "--no-tags",
    "--no-recurse-submodules",
    "--no-write-fetch-head",
    "--no-auto-maintenance",
    "--refmap=",
    "origin",
    "+refs/heads/*:refs/remotes/origin/*",
  ]);
}

export async function stableScan<T>(
  repo: string,
  config: SyncRepository,
  prepare: (
    objects: CommitObject[],
    info: ReturnType<typeof repositoryInfo>,
    tips: RefTips,
  ) => Promise<T>,
): Promise<{ prepared: T; tips: RefTips; observedAt: string }> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const info = ensureCompleteHistory(repo);
    if ((info.remote ?? null) !== config.canonical_remote)
      throw new Error(
        "Configured canonical remote differs from origin; confirm repository identity and update sync config",
      );
    const tips = captureRefs(repo, config.refs);
    const objects = scanObjects(repo, info, tips);
    const prepared = await prepare(objects, info, tips);
    const after = ensureCompleteHistory(repo);
    if (
      after.remote !== info.remote ||
      after.common !== info.common ||
      after.format !== info.format
    )
      throw new Error(
        "Repository identity changed during scan; prior observations are preserved",
      );
    if (sameRefs(tips, captureRefs(repo, config.refs)))
      return { prepared, tips, observedAt: new Date().toISOString() };
  }
  throw new Error(
    "Monitored refs moved during both scan attempts; retry when the repository is idle",
  );
}
