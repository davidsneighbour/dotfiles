import { spawnSync } from "node:child_process";

// A Git-backed vault must ignore generated private notes and operational state.
export function assertPrivate(vault: string, paths: string[]): void {
  const environment = { ...process.env };
  delete environment["GIT_DIR"];
  delete environment["GIT_WORK_TREE"];
  const options = {
    env: environment,
    encoding: "utf8" as const,
    maxBuffer: 16 * 1024 * 1024,
  };
  const repository = spawnSync(
    "git",
    ["-C", vault, "rev-parse", "--show-toplevel"],
    options,
  );
  if (repository.status !== 0) return;
  if (!paths.length) return;
  const unique = [...new Set(paths)];
  const tracked = spawnSync(
    "git",
    ["-C", vault, "ls-files", "-z", "--", ...unique],
    options,
  );
  const ignored = spawnSync(
    "git",
    ["-C", vault, "check-ignore", "--no-index", "-z", "--stdin"],
    { ...options, input: `${unique.join("\0")}\0` },
  );
  if (
    tracked.status !== 0 ||
    tracked.stdout ||
    ignored.error ||
    ignored.status !== 0 ||
    ignored.stdout.split("\0").filter(Boolean).length !== unique.length
  )
    throw new Error(
      "Generated records must be untracked and ignored in a Git-backed vault; add narrow local exclusions before writing",
    );
}
