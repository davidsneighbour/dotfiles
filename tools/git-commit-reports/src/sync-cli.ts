import { parseArgs } from "node:util";
import { syncVault } from "./sync.ts";

const help = `Usage: npm run sync --workspace @davidsneighbour/git-commit-reports -- --vault PATH [--dry-run] [--verbose | --quiet]

Sync repositories configured in .obsidian/git-commit-reports/config.json.
  --vault PATH  Existing Obsidian vault
  --dry-run     Inspect local refs without fetching, locking, logging, or writing
  --verbose     Show counts for each repository (also DNB_VERBOSE=1)
  --quiet       Suppress successful output; takes precedence over --verbose
  --help        Show this help

Normal sync uses the shared logger under ~/.logs/daily-reports/.
Fetch is opt-in per repository. Complete scans preserve old objects and track monitored-ref reachability.
`;
try {
  const { values } = parseArgs({
    options: {
      vault: { type: "string" },
      "dry-run": { type: "boolean" },
      verbose: { type: "boolean" },
      quiet: { type: "boolean" },
      help: { type: "boolean" },
    },
    allowPositionals: false,
  });
  if (values.help) console.log(help);
  else if (!values.vault) {
    console.error(help);
    process.exitCode = 1;
  } else {
    if (values.quiet) delete process.env["DNB_VERBOSE"];
    else if (values.verbose) process.env["DNB_VERBOSE"] = "1";
    const verbose = process.env["DNB_VERBOSE"] === "1";
    // Wrapper suppresses successful console output while retaining counts in the log.
    const logging = process.env["GIT_COMMIT_REPORTS_LOGGING"] === "1";
    const result = await syncVault({
      vault: values.vault,
      dryRun: Boolean(values["dry-run"]),
      report: (outcome) => {
        if (!outcome.complete)
          console.error(`ERROR ${outcome.id}: ${outcome.error}`);
        else if (logging || (verbose && !values.quiet))
          console.log(
            `${outcome.id}: selected=${outcome.selected} changed=${outcome.changed}${values["dry-run"] ? " (local dry-run)" : ""}`,
          );
      },
    });
    if (logging || !values.quiet)
      console.log(
        `Sync ${result.dryRun ? "dry-run " : ""}finished: repositories=${result.repositories.length} failed=${result.failed}${result.recovered ? " recovered=1" : ""}`,
      );
    if (result.failed) process.exitCode = 1;
  }
} catch (error) {
  // Native parsing/IO exceptions can quote raw input, so keep them out of logs.
  const message =
    error instanceof Error &&
    error.name === "Error" &&
    !(error as NodeJS.ErrnoException).code
      ? error.message
      : "Check sync configuration, clone availability, vault permissions, and operational state";
  console.error(`ERROR Sync failed: ${message}`);
  process.exitCode = 1;
}
