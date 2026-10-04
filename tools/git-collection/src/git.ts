import { execFileSync, spawn, spawnSync } from "node:child_process";

const environment: NodeJS.ProcessEnv = {
  ...process.env,
  GIT_NO_REPLACE_OBJECTS: "1",
  GIT_OPTIONAL_LOCKS: "0",
  GIT_NO_LAZY_FETCH: "1",
  GIT_ALLOW_PROTOCOL: "",
  GIT_TERMINAL_PROMPT: "0",
};
// -C must select the requested repository even when invoked from another Git tool.
for (const key of [
  "GIT_DIR",
  "GIT_WORK_TREE",
  "GIT_COMMON_DIR",
  "GIT_INDEX_FILE",
  "GIT_NAMESPACE",
  "GIT_OBJECT_DIRECTORY",
  "GIT_ALTERNATE_OBJECT_DIRECTORIES",
]) {
  delete environment[key];
}

export function git(path: string, args: string[]): string {
  return execFileSync("git", ["-C", path, ...args], {
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
    env: environment,
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

export function gitExists(path: string, revision: string): boolean {
  return (
    spawnSync("git", ["-C", path, "cat-file", "-e", `${revision}^{commit}`], {
      env: environment,
      stdio: "ignore",
    }).status === 0
  );
}

export function snapshot(path: string): string[] {
  const refs = git(path, [
    "for-each-ref",
    "--format=%(objectname) %(objecttype) %(*objectname) %(*objecttype)",
  ]);
  const tips = refs.split("\n").flatMap((line) => {
    const [hash, type, peeled, peeledType] = line.split(" ");
    if (type === "commit" && hash) return [hash];
    if (peeledType === "commit" && peeled) return [peeled];
    // Tags of tags need recursive peeling; refs pointing to trees/blobs do not contain commits.
    if (type === "tag" && hash && gitExists(path, hash))
      return [git(path, ["rev-parse", `${hash}^{commit}`])];
    return [];
  });
  const head = spawnSync(
    "git",
    ["-C", path, "rev-parse", "--verify", "--quiet", "HEAD^{commit}"],
    {
      env: environment,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    },
  );
  if (head.status === 0) tips.push(head.stdout.trim());
  return [...new Set(tips)].sort();
}

/** Stream delimiter-framed output with bounded buffering and reap Git on every exit. */
export async function* gitFields(
  path: string,
  args: string[],
  input: string,
  delimiter: number,
): AsyncGenerator<string> {
  const child = spawn("git", ["-C", path, ...args], {
    env: environment,
    stdio: ["pipe", "pipe", "pipe"],
  });
  let stderr = "";
  child.stderr.on("data", (chunk: Buffer) => {
    stderr = (stderr + chunk.toString()).slice(-4096);
  });
  const completion = new Promise<void>((resolve, reject) => {
    child.once("error", reject);
    child.once("close", (code) =>
      code === 0
        ? resolve()
        : reject(new Error(`Git extraction failed (${code}): ${stderr}`)),
    );
  });
  void completion.catch(() => undefined);
  let inputError: Error | undefined;
  child.stdin.on("error", (error: Error) => {
    inputError = error;
  });
  child.stdin.end(input);
  let pending = Buffer.alloc(0);
  let completed = false;
  try {
    for await (const chunk of child.stdout) {
      pending = Buffer.concat([pending, chunk as Buffer]);
      let end = pending.indexOf(delimiter);
      while (end !== -1) {
        if (end > 64 * 1024 * 1024)
          throw new Error("Git field exceeds the 64 MiB collection limit.");
        yield pending.subarray(0, end).toString("utf8");
        pending = pending.subarray(end + 1);
        end = pending.indexOf(delimiter);
      }
      if (pending.length > 64 * 1024 * 1024)
        throw new Error("Git field exceeds the 64 MiB collection limit.");
    }
    await completion;
    if (inputError) throw new Error(`Git input failed: ${inputError.message}`);
    completed = true;
    if (pending.toString().trim())
      throw new Error("Incomplete Git record; import rolled back.");
  } finally {
    if (!completed) child.kill("SIGTERM");
    await completion.catch(() => undefined);
  }
}
