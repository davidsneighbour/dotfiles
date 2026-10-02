import { spawnSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { resolve } from "node:path";
import {
  type CommitObject,
  commitIdentity,
  type ObjectFormat,
} from "./model.ts";

export function git(
  repo: string,
  args: string[],
  options: { input?: string; timeout?: number } = {},
): Buffer {
  const environment: NodeJS.ProcessEnv = {
    ...process.env,
    GIT_NO_REPLACE_OBJECTS: "1",
    GIT_TERMINAL_PROMPT: "0",
    GIT_NO_LAZY_FETCH: "1",
    GIT_SSH_COMMAND:
      process.env["GIT_SSH_COMMAND"] ??
      "ssh -oBatchMode=yes -oConnectTimeout=15",
  };
  // An inherited shell Git context must not override the named repository.
  for (const key of [
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_COMMON_DIR",
    "GIT_OBJECT_DIRECTORY",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    "GIT_NAMESPACE",
    "GIT_SHALLOW_FILE",
  ])
    delete environment[key];
  const result = spawnSync(
    "git",
    ["--no-replace-objects", "-C", repo, ...args],
    {
      env: environment,
      maxBuffer: 128 * 1024 * 1024,
      input: options.input,
      timeout: options.timeout ?? 30000,
      stdio: [options.input === undefined ? "ignore" : "pipe", "pipe", "pipe"],
    },
  );
  if (result.error || result.status !== 0) {
    // Git stderr can contain credentials from repository configuration.
    throw new Error(
      `Git ${args[0]} failed; check the repository, revision, and local object availability`,
    );
  }
  if (
    args[0] === "rev-parse" &&
    /ambiguous/i.test(result.stderr.toString("utf8"))
  )
    throw new Error(
      "Ambiguous revision; use a full hash or fully qualified ref",
    );
  return result.stdout;
}
const output = (repo: string, args: string[]): string =>
  git(repo, args).toString("utf8").trim();

export function repositoryInfo(repo: string): {
  common: string;
  remote: string | undefined;
  format: ObjectFormat;
} {
  const common = realpathSync(
    resolve(repo, output(repo, ["rev-parse", "--git-common-dir"])),
  );
  const format = output(repo, ["rev-parse", "--show-object-format"]);
  if (format !== "sha1" && format !== "sha256")
    throw new Error("Unsupported Git object format");
  const remotes = output(repo, ["remote"]).split("\n");
  const raw = remotes.includes("origin")
    ? output(repo, ["remote", "get-url", "origin"])
    : undefined;
  // Filesystem origins are clone locations, not portable repository identities.
  const localRemote =
    raw &&
    (raw.startsWith("/") ||
      raw.startsWith("./") ||
      raw.startsWith("../") ||
      raw.startsWith("file:") ||
      (!raw.includes("://") && !raw.includes(":")));
  return {
    common,
    remote: raw && !localRemote ? canonicalRemote(raw) : undefined,
    format,
  };
}

export function canonicalRemote(raw: string): string {
  const scp = /^(?:[^@/]+@)?([^/:]+):(.+)$/.exec(raw);
  let host: string;
  let path: string;
  if (!raw.includes("://") && scp) {
    host = scp[1] ?? "";
    path = scp[2] ?? "";
  } else {
    let url: URL;
    try {
      url = new URL(raw);
    } catch {
      throw new Error(
        "Origin must be a hosted URL; use explicit repository identity for local remotes",
      );
    }
    if (!["https:", "http:", "ssh:", "git:"].includes(url.protocol))
      throw new Error("Unsupported remote protocol");
    host = url.host;
    path = url.pathname;
  }
  path = path.replace(/^\/+|\/+$/g, "").replace(/\.git$/, "");
  if (
    !/^[a-zA-Z0-9._/-]+$/.test(path) ||
    path.split("/").some((part) => !part || part === "." || part === "..")
  )
    throw new Error("Invalid remote path");
  return `https://${host.toLowerCase()}/${host.toLowerCase() === "github.com" ? path.toLowerCase() : path}`;
}

export function resolveCommit(
  repo: string,
  revision: string,
  format: ObjectFormat,
): string {
  const hash = output(repo, [
    "rev-parse",
    "--verify",
    "--end-of-options",
    revision,
  ]);
  commitIdentity(format, hash);
  if (output(repo, ["cat-file", "-t", hash]) !== "commit")
    throw new Error(
      "Revision must name a commit object, not a tag, tree, or blob",
    );
  return hash;
}

function identity(line: string): {
  name: string;
  email: string;
  timestamp: string;
} {
  const match = /^(.*) <([^>]*)> (-?\d+) ([+-])(\d{2})(\d{2})$/.exec(line);
  if (!match) throw new Error("Invalid raw commit identity");
  const seconds = Number(match[3]);
  const hours = Number(match[5]);
  const minutes = Number(match[6]);
  if (hours > 23 || minutes > 59)
    throw new Error("Invalid commit timezone offset");
  const offset = (hours * 60 + minutes) * (match[4] === "+" ? 1 : -1);
  const local = new Date((seconds + offset * 60) * 1000)
    .toISOString()
    .slice(0, 19);
  return {
    name: match[1] ?? "",
    email: match[2] ?? "",
    timestamp: `${local}${match[4]}${match[5]}:${match[6]}`,
  };
}

export function readCommit(
  repo: string,
  hash: string,
  format: ObjectFormat,
): CommitObject {
  commitIdentity(format, hash);
  return parseCommit(hash, format, git(repo, ["cat-file", "commit", hash]));
}
export function parseCommit(
  hash: string,
  format: ObjectFormat,
  raw: Buffer,
): CommitObject {
  commitIdentity(format, hash);
  const separator = raw.indexOf(Buffer.from("\n\n"));
  if (separator < 0) throw new Error("Commit has no message separator");
  const headers = new TextDecoder("utf-8", { fatal: true })
    .decode(raw.subarray(0, separator))
    .split("\n");
  const encoding =
    headers.find((line) => line.startsWith("encoding "))?.slice(9) ?? "utf-8";
  let message: string;
  try {
    message = new TextDecoder(encoding, { fatal: true }).decode(
      raw.subarray(separator + 2),
    );
  } catch {
    throw new Error(
      "Commit message encoding is unsupported or invalid; original object is preserved",
    );
  }
  if (message.includes("\0"))
    throw new Error(
      "Commit message contains NUL and cannot be stored in Markdown",
    );
  const author = identity(
    headers.find((line) => line.startsWith("author "))?.slice(7) ?? "",
  );
  const committer = identity(
    headers.find((line) => line.startsWith("committer "))?.slice(10) ?? "",
  );
  const parents = headers
    .filter((line) => line.startsWith("parent "))
    .map((line) => line.slice(7));
  for (const parent of parents) commitIdentity(format, parent);
  return {
    hash,
    object_format: format,
    message,
    title: message.split(/\r?\n/)[0] || "(empty message)",
    authored_at: author.timestamp,
    committed_at: committer.timestamp,
    author_name: author.name,
    author_email: author.email,
    committer_name: committer.name,
    committer_email: committer.email,
    parents,
  };
}

export interface Selection {
  commit?: string | undefined;
  recent?: number | undefined;
  from?: string | undefined;
  to?: string | undefined;
  ref?: string | undefined;
}
export function dateBoundary(date: string): number {
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
    new Date(`${date}T00:00:00Z`).toISOString().slice(0, 10) !== date
  )
    throw new Error("Use valid YYYY-MM-DD calendar dates");
  return Date.parse(`${date}T00:00:00+07:00`) / 1000;
}
export function selectCommits(
  repo: string,
  format: ObjectFormat,
  selection: Selection,
): CommitObject[] {
  if (selection.commit)
    return [
      readCommit(repo, resolveCommit(repo, selection.commit, format), format),
    ];
  const tip = resolveCommit(repo, selection.ref ?? "HEAD", format);
  const args = ["rev-list", "--topo-order"];
  if (selection.recent !== undefined)
    args.push(`--max-count=${selection.recent}`);
  args.push(tip, "--");
  const hashes = output(repo, args).split("\n").filter(Boolean);
  const commits = hashes.map((hash) => readCommit(repo, hash, format));
  if (!selection.from || !selection.to) return commits;
  const start = dateBoundary(selection.from);
  const end = dateBoundary(selection.to) + 86400;
  if (start >= end) throw new Error("--from must be on or before --to");
  return commits.filter((commit) => {
    const seconds = Date.parse(commit.committed_at) / 1000;
    return seconds >= start && seconds < end;
  });
}

export function readAvailableCommits(
  repo: string,
  hashes: string[],
  format: ObjectFormat,
): Map<string, CommitObject> {
  for (const hash of hashes) commitIdentity(format, hash);
  const result = new Map<string, CommitObject>();
  if (!hashes.length) return result;
  const data = git(repo, ["cat-file", "--batch"], {
    input: `${hashes.join("\n")}\n`,
  });
  let offset = 0;
  for (const expected of hashes) {
    const end = data.indexOf(10, offset);
    if (end < 0) throw new Error("Incomplete Git batch header");
    const header = data.subarray(offset, end).toString("ascii").split(" ");
    offset = end + 1;
    if (header[0] !== expected) throw new Error("Git batch identity conflict");
    if (header[1] === "missing") continue;
    const size = Number(header[2]);
    if (
      header[1] !== "commit" ||
      !Number.isSafeInteger(size) ||
      size < 0 ||
      offset + size >= data.length ||
      data[offset + size] !== 10
    )
      throw new Error("Invalid Git batch commit framing");
    result.set(
      expected,
      parseCommit(expected, format, data.subarray(offset, offset + size)),
    );
    offset += size + 1;
  }
  if (offset !== data.length)
    throw new Error("Unexpected trailing Git batch output");
  return result;
}
