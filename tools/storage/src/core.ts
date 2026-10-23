import { execFileSync } from "node:child_process";
import { mkdir, readFile, realpath, stat } from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve, sep } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { fileURLToPath } from "node:url";

export interface Config {
  root: string;
  mountUuid: string | null;
  database: string;
  port: number;
  exclude: string[];
  hashBudgetMinutes: number;
  openerEnvironment?: Partial<
    Record<"DISPLAY" | "XAUTHORITY" | "DBUS_SESSION_BUS_ADDRESS", string>
  >;
}
export const defaultConfig = fileURLToPath(
  new URL("../config.json", import.meta.url),
);
export async function loadConfig(path = defaultConfig): Promise<Config> {
  const value: unknown = JSON.parse(await readFile(path, "utf8"));
  if (!value || typeof value !== "object")
    throw Error("Configuration must be an object.");
  const c = value as Record<string, unknown>;
  if (
    typeof c.root !== "string" ||
    !isAbsolute(c.root) ||
    typeof c.database !== "string" ||
    !(c.mountUuid === null || typeof c.mountUuid === "string") ||
    typeof c.port !== "number" ||
    !Number.isInteger(c.port) ||
    c.port < 1024 ||
    c.port > 65535 ||
    !Array.isArray(c.exclude) ||
    !c.exclude.every(
      (p: unknown) =>
        typeof p === "string" &&
        p !== "" &&
        !isAbsolute(p) &&
        !p.split("/").includes(".."),
    ) ||
    typeof c.hashBudgetMinutes !== "number" ||
    !Number.isFinite(c.hashBudgetMinutes) ||
    c.hashBudgetMinutes <= 0
  ) {
    throw Error(
      "Invalid configuration. See tools/storage/config.json for the required fields.",
    );
  }
  if (c.openerEnvironment !== undefined) {
    if (
      !c.openerEnvironment ||
      typeof c.openerEnvironment !== "object" ||
      Array.isArray(c.openerEnvironment) ||
      !Object.entries(c.openerEnvironment).every(
        ([key, value]) =>
          ["DISPLAY", "XAUTHORITY", "DBUS_SESSION_BUS_ADDRESS"].includes(key) &&
          typeof value === "string" &&
          !value.includes("\0"),
      )
    ) {
      throw Error(
        "openerEnvironment must contain only DISPLAY, XAUTHORITY, and DBUS_SESSION_BUS_ADDRESS strings.",
      );
    }
  }
  const config = c as unknown as Config;
  config.root = resolve(config.root);
  config.database = resolve(dirname(resolve(path)), config.database);
  if (inside(config.root, config.database))
    throw Error("Keep the database outside the indexed drive.");
  return config;
}
export function inside(root: string, path: string): boolean {
  const rel = relative(root, path);
  return (
    rel === "" ||
    (rel !== ".." && !rel.startsWith(`..${sep}`) && !isAbsolute(rel))
  );
}
export async function verifyDrive(config: Config): Promise<string> {
  if (!(await stat(config.root)).isDirectory())
    throw Error("Storage root is not a directory.");
  if ((await realpath(config.root)) !== config.root)
    throw Error("Storage root must not be a symlink.");
  if (config.mountUuid !== null) {
    const uuid = execFileSync(
      "/usr/bin/findmnt",
      ["-rn", "-M", config.root, "-o", "UUID"],
      { encoding: "utf8" },
    ).trim();
    if (uuid !== config.mountUuid)
      throw Error(
        "Configured storage drive is absent or its UUID does not match.",
      );
  }
  const s = await stat(config.root);
  return `${s.dev}:${s.ino}`;
}
export async function openDatabase(config: Config): Promise<DatabaseSync> {
  await mkdir(dirname(config.database), { recursive: true, mode: 0o700 });
  const db = new DatabaseSync(config.database);
  db.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA busy_timeout=5000;
    CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) STRICT;
    CREATE TABLE IF NOT EXISTS entries (
      id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE, name TEXT NOT NULL, kind TEXT NOT NULL,
      extension TEXT NOT NULL, size INTEGER NOT NULL, mtime REAL NOT NULL, ctime REAL NOT NULL,
      birthtime REAL, dev TEXT NOT NULL, ino TEXT NOT NULL, fingerprint TEXT NOT NULL, hash TEXT, error TEXT, seen TEXT NOT NULL
    ) STRICT;
    CREATE INDEX IF NOT EXISTS entries_name ON entries(name COLLATE NOCASE);
    CREATE INDEX IF NOT EXISTS entries_extension ON entries(extension);
    CREATE INDEX IF NOT EXISTS entries_hash ON entries(hash) WHERE hash IS NOT NULL;
    CREATE INDEX IF NOT EXISTS entries_mtime ON entries(mtime);
    CREATE INDEX IF NOT EXISTS entries_birthtime ON entries(birthtime);
    CREATE INDEX IF NOT EXISTS entries_kind ON entries(kind);
  `);
  const root = db.prepare("SELECT value FROM meta WHERE key=?").get("root");
  if (root && root.value !== config.root) {
    db.close();
    throw Error(
      "Database belongs to a different storage root. Use a separate database.",
    );
  }
  setMeta(db, "root", config.root);
  return db;
}
export function setMeta(db: DatabaseSync, key: string, value: string): void {
  db.prepare("INSERT OR REPLACE INTO meta VALUES (?,?)").run(key, value);
}
export function status(db: DatabaseSync): object {
  return {
    ...db
      .prepare(`SELECT count(*) AS entries, sum(kind='file') AS files, sum(kind='directory') AS folders,
      sum(kind='file' AND hash IS NOT NULL) AS hashed, sum(error IS NOT NULL) AS errors,
      coalesce(sum(CASE WHEN kind='file' AND hash IS NULL THEN size ELSE 0 END),0) AS pendingBytes FROM entries`)
      .get(),
    meta: Object.fromEntries(
      db
        .prepare("SELECT * FROM meta")
        .all()
        .map((r) => [r.key, r.value]),
    ),
  };
}
