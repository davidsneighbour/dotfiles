import { parseArgs } from "node:util";
import { importCommits } from "./importer.ts";

const help = `Usage: npm run import --workspace @davidsneighbour/git-commit-reports -- --repo PATH --vault PATH SELECTION

Selection (choose one):
  --commit REVISION       One exact commit object
  --recent COUNT          First COUNT commits in topological traversal, including merges
  --from YYYY-MM-DD --to YYYY-MM-DD   Inclusive committer dates in Asia/Bangkok

Options:
  --ref REVISION          History tip (default HEAD; not with --commit)
  --repository-id ID      Explicit persisted identity; new registrations use local-UUID
  --dry-run              Inspect without creating files, directories, or registrations
  --verbose              Print selection and registration counts
  --quiet                Suppress successful output
  --help                 Show this help

The vault must already exist. No fetch, checkout, lifecycle reconciliation, or cron changes occur.
`;
try {
  const { values } = parseArgs({
    options: {
      repo: { type: "string" },
      vault: { type: "string" },
      commit: { type: "string" },
      recent: { type: "string" },
      from: { type: "string" },
      to: { type: "string" },
      ref: { type: "string" },
      "repository-id": { type: "string" },
      "dry-run": { type: "boolean" },
      verbose: { type: "boolean" },
      quiet: { type: "boolean" },
      help: { type: "boolean" },
    },
    allowPositionals: false,
  });
  if (values.help) console.log(help);
  else if (
    !values.repo ||
    !values.vault ||
    (!values.commit && !values.recent && !values.from && !values.to)
  ) {
    console.error(help);
    process.exitCode = 1;
  } else {
    if (values.verbose && values.quiet)
      throw new Error("Choose --verbose or --quiet");
    if (values.recent !== undefined && !/^[1-9]\d*$/.test(values.recent))
      throw new Error("--recent must be a positive integer");
    const result = await importCommits({
      repo: values.repo,
      vault: values.vault,
      commit: values.commit,
      recent: values.recent === undefined ? undefined : Number(values.recent),
      from: values.from,
      to: values.to,
      ref: values.ref,
      repositoryId: values["repository-id"],
      dryRun: values["dry-run"],
    });
    if (!values.quiet)
      console.log(
        `${result.dryRun ? "Would change" : "Changed"} ${result.changed} notes.${values.verbose ? ` Selected ${result.selected} commits; repository ${result.repositoryId}.` : ""}`,
      );
  }
} catch (error) {
  console.error(
    `Import failed: ${error instanceof Error ? error.message : "Unknown error"}`,
  );
  process.exitCode = 1;
}
