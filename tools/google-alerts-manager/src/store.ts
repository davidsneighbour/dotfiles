import { randomUUID } from "node:crypto";
import {
  chmod,
  lstat,
  mkdir,
  open,
  readFile,
  rename,
  rm,
} from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import type { State } from "./model.ts";
import { bytesHash, stateSchema } from "./model.ts";
import type { inspectTakeout } from "./takeout.ts";
export async function privateDirectory(path: string): Promise<void> {
  const absolute = resolve(path);
  let current = "/";
  for (const part of absolute.split("/").filter(Boolean)) {
    current = join(current, part);
    try {
      const s = await lstat(current);
      if (!s.isDirectory() || s.isSymbolicLink())
        throw new Error("Unsafe local directory");
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      await mkdir(current, { mode: 0o700 });
    }
  }
  await chmod(absolute, 0o700);
}
export async function writePrivate(
  path: string,
  value: string | Buffer,
  exclusive = false,
): Promise<void> {
  await privateDirectory(dirname(path));
  if (exclusive) {
    const f = await open(path, "wx", 0o600);
    try {
      await f.writeFile(value);
      await f.sync();
    } finally {
      await f.close();
    }
    return;
  }
  try {
    const s = await lstat(path);
    if (!s.isFile() || s.isSymbolicLink()) throw new Error("Unsafe local file");
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code !== "ENOENT") throw e;
  }
  const temp = `${path}.${randomUUID()}.tmp`;
  const f = await open(temp, "wx", 0o600);
  try {
    await f.writeFile(value);
    await f.sync();
  } finally {
    await f.close();
  }
  try {
    await rename(temp, path);
  } finally {
    await rm(temp, { force: true });
  }
}
export async function loadState(root: string): Promise<State | undefined> {
  const path = join(root, "state.json");
  try {
    const s = await lstat(path);
    if (!s.isFile() || s.isSymbolicLink()) throw new Error("Unsafe state file");
    return stateSchema.parse(JSON.parse(await readFile(path, "utf8")));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return undefined;
    throw new Error(
      "Cannot read state safely; no automatic reset or migration",
    );
  }
}
export async function withLock<T>(
  root: string,
  work: () => Promise<T>,
): Promise<T> {
  await privateDirectory(root);
  const path = join(root, "write.lock");
  let lock;
  try {
    lock = await open(path, "wx", 0o600);
  } catch {
    throw new Error(
      "Local state is locked; inspect the previous process before removing write.lock",
    );
  }
  try {
    await lock.writeFile(String(process.pid));
    return await work();
  } finally {
    await lock.close();
    await rm(path);
  }
}
export async function saveState(root: string, state: State): Promise<void> {
  stateSchema.parse(state);
  await writePrivate(
    join(root, "state.json"),
    JSON.stringify(state, null, 2) + "\n",
  );
}
export async function applyImport(
  root: string,
  result: Awaited<ReturnType<typeof inspectTakeout>>,
) {
  return withLock(root, async () => {
    const previous = await loadState(root);
    if (previous?.imports.some((i) => i.digest === result.digest)) {
      const existing = join(root, "snapshots", result.digest + ".json");
      try {
        const meta = await lstat(existing);
        if (
          !meta.isFile() ||
          meta.isSymbolicLink() ||
          bytesHash(await readFile(existing)) !== result.digest
        )
          throw new Error();
      } catch {
        throw new Error("Snapshot integrity check failed");
      }
      return { changed: false, state: previous };
    }
    const snapshot = `snapshots/${result.digest}.json`;
    const path = join(root, snapshot);
    try {
      await writePrivate(path, result.payload, true);
    } catch (e) {
      if ((e as NodeJS.ErrnoException).code !== "EEXIST") throw e;
      if (
        (await lstat(path)).isSymbolicLink() ||
        bytesHash(await readFile(path)) !== result.digest
      )
        throw new Error("Snapshot integrity check failed");
    }
    const manifest = {
      digest: result.digest,
      snapshot,
      count: result.records.length,
    };
    const state: State = previous
      ? { ...previous, imports: [...previous.imports, manifest] }
      : {
          schemaVersion: 1,
          initialSource: "authoritative-takeout",
          initialDigest: result.digest,
          imports: [manifest],
          initial: result.records,
          managed: [],
        };
    await saveState(root, state);
    return { changed: true, state };
  });
}
