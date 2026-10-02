export type ObjectFormat = "sha1" | "sha256";
export type Reachability = "reachable" | "unreachable" | "unknown";
export const STORAGE_TIMEZONE = "Asia/Bangkok";

export interface CommitObject {
  hash: string;
  object_format: ObjectFormat;
  title: string;
  message: string;
  authored_at: string;
  committed_at: string;
  author_name: string;
  author_email: string;
  committer_name: string;
  committer_email: string;
  parents: string[];
}

export interface RepositoryRecord {
  type: "git-repository";
  schema_version: 1;
  repository_id: string;
  title: string;
  host: string;
  slug: string;
  former_slugs: string[];
  url?: string;
  retired: boolean;
  created: string;
  updated: string;
  labels: string[];
}

export interface MembershipObservation {
  repository_id: string;
  status: Reachability;
}

export function commitIdentity(format: ObjectFormat, hash: string): string {
  const length = format === "sha1" ? 40 : 64;
  if (!new RegExp(`^[0-9a-f]{${length}}$`).test(hash)) {
    throw new Error(`Expected a full lowercase ${format} commit hash`);
  }
  return `${format}:${hash}`;
}

export function aggregateStatus(
  observations: readonly MembershipObservation[],
): Reachability {
  if (observations.some((entry) => entry.status === "reachable"))
    return "reachable";
  if (
    observations.length === 0 ||
    observations.some((entry) => entry.status === "unknown")
  ) {
    return "unknown";
  }
  return "unreachable";
}

export function commitDate(
  timestamp: string,
  timezone = STORAGE_TIMEZONE,
): string {
  // Require an explicit offset: host-local parsing would make paths machine-dependent.
  if (
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})$/.test(
      timestamp,
    )
  ) {
    throw new Error(
      "Commit timestamp must include seconds and an explicit timezone offset",
    );
  }
  const wallTime = timestamp.slice(0, 19);
  const wallInstant = new Date(`${wallTime}Z`);
  if (
    !Number.isFinite(wallInstant.getTime()) ||
    wallInstant.toISOString().slice(0, 19) !== wallTime
  ) {
    throw new Error("Invalid calendar date or time");
  }
  const instant = new Date(timestamp);
  if (!Number.isFinite(instant.getTime()))
    throw new Error("Invalid commit timestamp");
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(instant);
  const part = (name: string): string => {
    const value = parts.find((entry) => entry.type === name)?.value;
    if (!value) throw new Error(`Missing date component: ${name}`);
    return value;
  };
  return `${part("year")}-${part("month")}-${part("day")}`;
}

export function commitItemPath(
  commit: Pick<CommitObject, "hash" | "object_format" | "committed_at">,
): string {
  commitIdentity(commit.object_format, commit.hash);
  const date = commitDate(commit.committed_at);
  return `23 Eventlog/Github/items/${date.replaceAll("-", "/")}/${commit.hash}.md`;
}
