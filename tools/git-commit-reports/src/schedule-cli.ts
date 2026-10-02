import { parseArgs } from "node:util";
import { scheduledSync } from "./schedule.ts";

const help = `Usage: cron.sh --node ABSOLUTE_PATH --vault PATH [--if-due] [--dry-run] [--verbose | --quiet]

  --vault PATH  Existing vault with sync configuration
  --if-due      Skip after a successful run for the current 08:00 Bangkok cycle
  --dry-run     Inspect without logging, locking, fetching, or writing
  --verbose     Print repository counts (also DNB_VERBOSE=1)
  --quiet       Suppress successful output; errors remain visible
  --help        Show help
Failures do not complete the cycle; the catch-up job retries them.
`;
try {
  const { values } = parseArgs({
    options: {
      vault: { type: "string" },
      "if-due": { type: "boolean" },
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
    const logging = process.env["GIT_COMMIT_REPORTS_LOGGING"] === "1";
    const result = await scheduledSync({
      vault: values.vault,
      ifDue: Boolean(values["if-due"]),
      dryRun: Boolean(values["dry-run"]),
      report: (outcome) => {
        if (!outcome.complete)
          console.error(`ERROR ${outcome.id}: ${outcome.error}`);
        else if (
          logging ||
          (!values.quiet && process.env["DNB_VERBOSE"] === "1")
        )
          console.log(
            `${outcome.id}: selected=${outcome.selected} changed=${outcome.changed}`,
          );
      },
    });
    if (logging || !values.quiet)
      console.log(
        result
          ? `Sync scheduled run finished: repositories=${result.repositories.length} failed=${result.failed}`
          : "Sync scheduled run skipped: cycle already complete",
      );
    if (result?.failed) process.exitCode = 1;
  }
} catch (error) {
  console.error(
    `ERROR ${error instanceof Error && error.name === "Error" && !(error as NodeJS.ErrnoException).code ? error.message : "Scheduled sync failed; check runtime paths, configuration, permissions, and scheduler state"}`,
  );
  process.exitCode = 1;
}
