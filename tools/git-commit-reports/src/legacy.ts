import { canonicalRemote, dateBoundary } from "./git.ts";
import { ARCHIVE, notes, strings } from "./vault.ts";

export interface LegacyEvidence {
  report: string;
  line: number;
  repository_url: string;
  hash: string;
  date: string;
  title: string;
  url: string;
}
export interface Inventory {
  reports: number;
  occurrences: number;
  hashes: number;
  memberships: number;
  duplicates: number;
  conflicting_titles: number;
  evidence: LegacyEvidence[];
}
export async function inventoryLegacy(vault: string): Promise<Inventory> {
  const evidence: LegacyEvidence[] = [];
  let reports = 0;
  for (const [path, note] of await notes(vault, ARCHIVE)) {
    if (
      /\/(?:items|repositories|observations)\//.test(path) ||
      note.properties["type"]?.toString().startsWith("git-")
    )
      continue;
    const tags =
      note.properties["tags"] === undefined
        ? []
        : strings(note.properties["tags"], "tags");
    if (
      !tags.includes("gitreport") &&
      !/\/(?:\d{4}\/\d{2}\/\d{2}-[A-Za-z]+|\d{4}-\d{2}-\d{2}_to_\d{4}-\d{2}-\d{2})\.md$/.test(
        path,
      )
    )
      continue;
    reports++;
    const title = note.properties["title"];
    const start =
      typeof title === "string"
        ? /^(\d{4}-\d{2}-\d{2})(?:$| to )/.exec(title)?.[1]
        : undefined;
    const pathDate = /\/(\d{4})\/(\d{2})\/(\d{2})-/.exec(path);
    const provisional =
      start ??
      (pathDate
        ? `${pathDate[1]}-${pathDate[2]}-${pathDate[3]}`
        : /\/(\d{4}-\d{2}-\d{2})_to_/.exec(path)?.[1]);
    if (!provisional)
      throw new Error(
        "A legacy report has no evidenced calendar date; resolve its date before migration",
      );
    dateBoundary(provisional);
    for (const [index, line] of note.source.split(/\r?\n/).entries()) {
      for (const match of line.matchAll(
        /\]\((https:\/\/github\.com\/([^\s/()]+\/[^\s/()]+)\/commit\/([0-9a-f]{64}|[0-9a-f]{40}))\)/g,
      )) {
        const date = /\*\*(\d{4}-\d{2}-\d{2})\s/.exec(line)?.[1] ?? provisional;
        dateBoundary(date);
        evidence.push({
          report: path,
          line: index + 1,
          repository_url: canonicalRemote(`https://github.com/${match[2]}`),
          hash: match[3] ?? "",
          date,
          title: line.slice((match.index ?? 0) + match[0].length).trim(),
          url: match[1] ?? "",
        });
      }
    }
  }
  evidence.sort(
    (a, b) =>
      a.date.localeCompare(b.date) ||
      a.report.localeCompare(b.report) ||
      a.line - b.line,
  );
  const groups = new Map<string, Set<string>>();
  for (const entry of evidence) {
    const titles = groups.get(entry.hash) ?? new Set<string>();
    titles.add(entry.title);
    groups.set(entry.hash, titles);
  }
  const memberships = new Set(
    evidence.map((entry) => `${entry.repository_url}:${entry.hash}`),
  ).size;
  return {
    reports,
    occurrences: evidence.length,
    hashes: groups.size,
    memberships,
    duplicates: evidence.length - memberships,
    conflicting_titles: [...groups.values()].filter((titles) => titles.size > 1)
      .length,
    evidence,
  };
}
