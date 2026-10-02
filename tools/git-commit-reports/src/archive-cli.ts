import { parseArgs } from "node:util";
import { inventoryLegacy } from "./legacy.ts";
import { migrateLegacy } from "./migrate.ts";
import { installViews } from "./views.ts";

const help = `Usage: npm run archive --workspace @davidsneighbour/git-commit-reports -- --vault PATH --action inventory|migrate|views [OPTIONS]

  --vault PATH       Existing vault
  --action ACTION    inventory (read only), migrate, or views
  --clone-root PATH  Root containing owner/repository clones; repeatable for migrate
  --dry-run          Do not write, register, fetch, lock, or log
  --verbose          Print progress (also DNB_VERBOSE=1)
  --quiet            Suppress successful output; overrides verbose
  --help             Show help

Migration never rewrites legacy reports. Git-backed vaults must ignore private generated records.
Views preserve custom Base definitions. Enrichment retains redirects at provisional paths.
`;
try {
  const { values } = parseArgs({
    options: {
      vault: { type: "string" },
      action: { type: "string" },
      "clone-root": { type: "string", multiple: true },
      "dry-run": { type: "boolean" },
      verbose: { type: "boolean" },
      quiet: { type: "boolean" },
      help: { type: "boolean" },
    },
    allowPositionals: false,
  });
  if (values.help) console.log(help);
  else if (!values.vault || !values.action) {
    console.error("ERROR --vault and --action are required");
    console.error(help);
    process.exitCode = 1;
  } else {
    if (values.quiet) delete process.env["DNB_VERBOSE"];
    else if (values.verbose) process.env["DNB_VERBOSE"] = "1";
    const logging = process.env["GIT_COMMIT_REPORTS_LOGGING"] === "1";
    const verbose =
      !values.quiet && (values.verbose || process.env["DNB_VERBOSE"] === "1");
    let result: unknown;
    switch (values.action) {
      case "inventory": {
        const { evidence: _evidence, ...counts } = await inventoryLegacy(
          values.vault,
        );
        result = counts;
        break;
      }
      case "migrate":
        result = await migrateLegacy({
          vault: values.vault,
          cloneRoots: values["clone-root"] ?? [],
          dryRun: Boolean(values["dry-run"]),
          ...(verbose || logging
            ? { report: (message: string) => console.log(message) }
            : {}),
        });
        break;
      case "views":
        result = {
          changed: await installViews(values.vault, Boolean(values["dry-run"])),
        };
        break;
      default:
        throw new Error("--action must be inventory, migrate, or views");
    }
    if (logging || !values.quiet)
      console.log(`Archive ${JSON.stringify(result)}`);
  }
} catch (error) {
  console.error(
    "ERROR " +
      (error instanceof Error &&
      error.name === "Error" &&
      !(error as NodeJS.ErrnoException).code
        ? error.message
        : "Archive operation failed; check report dates, clone availability, vault permissions, and YAML/JSON state"),
  );
  process.exitCode = 1;
}
