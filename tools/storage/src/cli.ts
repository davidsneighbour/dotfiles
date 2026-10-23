import { spawnSync } from "node:child_process";
import { mkdir } from "node:fs/promises";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { loadConfig, openDatabase, status } from "./core.ts";
import { indexDrive } from "./indexer.ts";
import { serve } from "./server.ts";

const help = `Storage catalogue
Usage: node src/cli.ts --index|--serve|--status [options]
  --index           Scan names, then calculate SHA-256 hashes incrementally
  --serve           Search at http://127.0.0.1:8765 (port comes from config)
  --status          Print index coverage and update state as JSON
  --config PATH     JSON configuration (default: tools/storage/config.json)
  --metadata-only   Scan names and paths without calculating hashes
  --rehash          Discard cached hashes during this scan (expensive)
  --verbose         Print each hashed path; also honours DNB_VERBOSE=1
  --quiet           Disable verbose output (takes precedence)
  --help            Show this help
Example: node src/cli.ts --index --config config.json
`;
try {
  const { values } = parseArgs({
    options: {
      index: { type: "boolean" },
      serve: { type: "boolean" },
      status: { type: "boolean" },
      config: { type: "string" },
      "metadata-only": { type: "boolean" },
      rehash: { type: "boolean" },
      verbose: { type: "boolean" },
      quiet: { type: "boolean" },
      help: { type: "boolean" },
    },
  });
  if (values.help || ![values.index, values.serve, values.status].some(Boolean))
    console.log(help);
  else {
    if (
      [values.index, values.serve, values.status].filter(Boolean).length !== 1
    )
      throw Error("Choose exactly one action.");
    if ((values.rehash || values["metadata-only"]) && !values.index)
      throw Error("Hash options require --index.");
    const verbose =
      !values.quiet && (values.verbose || process.env.DNB_VERBOSE === "1");
    if (values.quiet) delete process.env.DNB_VERBOSE;
    else if (verbose) process.env.DNB_VERBOSE = "1";
    const config = await loadConfig(values.config);
    if (values.index) {
      await mkdir(dirname(config.database), { recursive: true, mode: 0o700 });
      // Kernel-held lock survives crashes safely and prevents overlapping cron/manual scans.
      if (process.env.STORAGE_INDEX_LOCK !== config.database) {
        const result = spawnSync(
          "/usr/bin/flock",
          [
            "-n",
            "-E",
            "75",
            `${config.database}.lock`,
            process.execPath,
            fileURLToPath(import.meta.url),
            ...process.argv.slice(2),
          ],
          {
            stdio: "inherit",
            env: { ...process.env, STORAGE_INDEX_LOCK: config.database },
          },
        );
        if (result.error) throw result.error;
        if (result.status === 75)
          console.log("Another storage update is running; skipped.");
        else process.exitCode = result.status ?? 1;
      } else {
        const abort = new AbortController();
        process.on("SIGINT", () =>
          abort.abort(Error("Stopped by SIGINT; completed work retained.")),
        );
        process.on("SIGTERM", () =>
          abort.abort(Error("Stopped by SIGTERM; completed work retained.")),
        );
        const errors = await indexDrive(config, {
          verbose,
          rehash: values.rehash,
          metadataOnly: values["metadata-only"],
          signal: abort.signal,
        });
        if (errors > 0) process.exitCode = 1;
      }
    } else if (values.status) {
      const db = await openDatabase(config);
      try {
        console.log(JSON.stringify(status(db), null, 2));
      } finally {
        db.close();
      }
    } else await serve(config);
  }
} catch (error) {
  console.error(
    `Storage: ${error instanceof Error ? error.message : String(error)}\nUse --help for usage.`,
  );
  process.exitCode = 1;
}
