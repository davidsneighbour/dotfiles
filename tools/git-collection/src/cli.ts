import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";
import { collect, safeError } from "./collector.ts";
import { openDatabase, rebuildSearch, verifyDatabase } from "./database.ts";
import { type DiscoveryConfig, discover, loadConfig } from "./discovery.ts";
import { enrich } from "./enrichment.ts";
import { search } from "./query.ts";
import { rebuild, snapshotDatabase } from "./recovery.ts";
import { generateReports } from "./reports.ts";
import { scanAll } from "./scanner.ts";

const help = `Git commit catalogue (Node 24 or newer)
Usage: node tools/git-collection/src/cli.ts <command> [flags]
Commands: init, status, verify, discover, scan, rebuild, search, reindex, backup, enrich, reports
Flags:
  --database PATH     SQLite file (default: ~/.local/share/git-collection/catalogue.sqlite)
  --repository PATH   One repository for scan; exact name, ID, or path filter for search
  --all               Scan configured discovery roots
  --config PATH       Discovery JSON (default: ~/.config/git-collection/config.json)
  --root PATH         Discovery root, repeatable; replaces configured roots
  --exclude PATH      Excluded subtree, repeatable (requires --root)
  --max-depth NUMBER  Discovery depth (default: 4; requires --root)
  --full              Extract full history instead of using ref checkpoints
  --destination PATH  New file for backup or rebuild; never overwrites
  --query TEXT        FTS5 search expression (search only)
  --author EMAIL      Exact author email filter (search only)
  --since YYYY-MM-DD  Inclusive Bangkok date filter (search only)
  --until YYYY-MM-DD  Inclusive Bangkok date filter (search only)
  --limit NUMBER      Search result count, 1–1000 (default: 50)
                      Enrichment batch size, 1–100000 (default: 500)
  --statistics        Enrich first-parent file change totals
  --files             Also store individual changed files (enrich only)
  --output PATH       Owned directory for disposable Markdown reports
  --verbose           Print database path and per-repository scan details
  --help              Show this help
Examples:
  node tools/git-collection/src/cli.ts scan --repository /path/to/repository
  node tools/git-collection/src/cli.ts scan --all --root /path/to/repositories
  node tools/git-collection/src/cli.ts search --query '"reduced motion"'
  node tools/git-collection/src/cli.ts rebuild --root /path/to/repositories --destination /tmp/rebuilt.sqlite`;

try {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      database: { type: "string" },
      repository: { type: "string" },
      config: { type: "string" },
      root: { type: "string", multiple: true },
      exclude: { type: "string", multiple: true },
      "max-depth": { type: "string" },
      all: { type: "boolean" },
      full: { type: "boolean" },
      destination: { type: "string" },
      query: { type: "string" },
      author: { type: "string" },
      since: { type: "string" },
      until: { type: "string" },
      limit: { type: "string" },
      statistics: { type: "boolean" },
      files: { type: "boolean" },
      output: { type: "string" },
      verbose: { type: "boolean" },
      help: { type: "boolean" },
    },
  });
  const command = positionals[0];
  if (values.help || !command) {
    console.log(help);
  } else {
    const allowed: Record<string, string[]> = {
      init: [],
      status: [],
      verify: [],
      reindex: [],
      discover: ["config", "root", "exclude", "max-depth"],
      scan: [
        "repository",
        "all",
        "config",
        "root",
        "exclude",
        "max-depth",
        "full",
      ],
      rebuild: ["config", "root", "exclude", "max-depth", "destination"],
      backup: ["destination"],
      search: ["query", "repository", "author", "since", "until", "limit"],
      enrich: ["repository", "statistics", "files", "limit"],
      reports: ["output"],
    };
    const flags = allowed[command];
    if (positionals.length !== 1 || !flags)
      throw new Error("Choose a command listed in --help.");
    for (const flag of Object.keys(values)) {
      if (!["database", "verbose", "help", ...flags].includes(flag))
        throw new Error(`--${flag} is not valid for ${command}.`);
    }
    if (
      command === "scan" &&
      Boolean(values.repository) === Boolean(values.all)
    ) {
      throw new Error(
        "scan requires exactly one of --repository PATH or --all.",
      );
    }
    if (
      values.repository &&
      command === "scan" &&
      (values.root || values.config)
    )
      throw new Error("Discovery flags require scan --all.");
    if (!values.root && (values.exclude || values["max-depth"]))
      throw new Error("--exclude and --max-depth require --root.");
    if (values.root && values.config)
      throw new Error("Use --root or --config, not both.");
    const config = (): DiscoveryConfig => {
      if (!values.root)
        return loadConfig(
          resolve(
            values.config ??
              join(homedir(), ".config/git-collection/config.json"),
          ),
        );
      const maxDepth = Number(values["max-depth"] ?? 4);
      if (!Number.isInteger(maxDepth) || maxDepth < 0 || maxDepth > 100)
        throw new Error("--max-depth must be from 0 to 100.");
      if (values.root.some((root) => !root.trim()))
        throw new Error("--root must be a non-empty path.");
      return {
        roots: values.root.map((root) => resolve(root)),
        exclude: (values.exclude ?? []).map((path) => resolve(path)),
        maxDepth,
      };
    };
    const path = resolve(
      values.database ??
        join(homedir(), ".local/share/git-collection/catalogue.sqlite"),
    );
    if (values.verbose) console.log(`Database: ${path}`);
    if (command === "discover") {
      const result = discover(config());
      console.log(JSON.stringify(result, null, 2));
      if (result.errors.length) process.exitCode = 1;
    } else if (command === "rebuild") {
      if (!values.destination)
        throw new Error(
          "rebuild requires --destination PATH for a new database.",
        );
      console.log(
        JSON.stringify(await rebuild(values.destination, config()), null, 2),
      );
    } else {
      if (command === "backup" && !values.destination)
        throw new Error(
          "backup requires --destination PATH for a new snapshot.",
        );
      if (command === "search" && !values.query)
        throw new Error("search requires --query TEXT.");
      if (command === "enrich" && !values.statistics && !values.files)
        throw new Error("enrich requires --statistics or --files.");
      if (command === "reports" && !values.output)
        throw new Error("reports requires --output PATH for generated files.");
      const discoveryConfig =
        command === "scan" && values.all ? config() : undefined;
      const db = openDatabase(
        path,
        ["init", "scan", "reindex", "enrich"].includes(command),
      );
      try {
        if (command === "scan" && discoveryConfig) {
          const result = await scanAll(db, path, discoveryConfig, values.full);
          console.log(
            JSON.stringify(
              values.verbose ? result : { ...result, repositories: undefined },
              null,
              2,
            ),
          );
          if (result.failures) process.exitCode = 1;
        } else if (command === "scan") {
          console.log(
            JSON.stringify(
              await collect(db, values.repository ?? "", values.full),
            ),
          );
        } else if (command === "status") {
          console.log(
            JSON.stringify(
              {
                schema: db.prepare("PRAGMA user_version").get()?.user_version,
                repositories: db
                  .prepare("SELECT count(*) AS count FROM repositories")
                  .get()?.count,
                commits: db
                  .prepare("SELECT count(*) AS count FROM commits")
                  .get()?.count,
                reachability: db
                  .prepare(
                    "SELECT reachability, count(*) AS count FROM commits GROUP BY reachability",
                  )
                  .all(),
                runs: db
                  .prepare(
                    "SELECT state, count(*) AS count FROM collection_runs GROUP BY state",
                  )
                  .all(),
                lastScan:
                  db
                    .prepare("SELECT * FROM scan_runs ORDER BY id DESC LIMIT 1")
                    .get() ?? null,
              },
              null,
              2,
            ),
          );
        } else if (command === "search") {
          console.log(
            JSON.stringify(
              search(db, {
                query: values.query ?? "",
                repository: values.repository,
                author: values.author,
                since: values.since,
                until: values.until,
                limit:
                  values.limit === undefined ? undefined : Number(values.limit),
              }),
              null,
              2,
            ),
          );
        } else if (command === "backup") {
          await snapshotDatabase(db, values.destination ?? "");
          console.log(
            `Verified snapshot: ${resolve(values.destination ?? "")}`,
          );
        } else if (command === "enrich") {
          const result = await enrich(db, {
            repository: values.repository,
            files: values.files,
            limit:
              values.limit === undefined ? undefined : Number(values.limit),
          });
          console.log(JSON.stringify(result, null, 2));
          if (result.failures) process.exitCode = 1;
        } else if (command === "reports") {
          console.log(
            JSON.stringify(generateReports(db, values.output ?? ""), null, 2),
          );
        } else if (command === "reindex") {
          rebuildSearch(db);
          verifyDatabase(db);
          console.log("Search index rebuilt.");
        } else {
          verifyDatabase(db);
          console.log(
            command === "init" ? "Database ready." : "Integrity checks passed.",
          );
        }
      } finally {
        db.close();
      }
    }
  }
} catch (error) {
  console.error(`git-catalog: ${safeError(error)}`);
  console.error(help);
  process.exitCode = 1;
}
