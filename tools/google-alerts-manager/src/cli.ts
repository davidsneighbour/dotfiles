#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";
import { stringify } from "yaml";
import { probeBrowser, refuseLiveApply } from "./browser.ts";
import { candidateConfig, readConfig, resolveConfig } from "./config.ts";
import {
  adopt,
  adoptionPlan,
  observationSchema,
  reconcile,
} from "./reconcile.ts";
import {
  applyImport,
  loadState,
  saveState,
  withLock,
  writePrivate,
} from "./store.ts";
import { inspectTakeout } from "./takeout.ts";

process.umask(0o077);
const HELP = `Google Alerts Manager (Node 24+)\n\n  import --from-takeout FILE [--apply]\n  inventory\n  topics [--apply]                 Write private candidate YAML once\n  validate [--config FILE]\n  adoption-plan\n  adopt --all --approve DIGEST [--apply]   Local ownership only\n  plan [--config FILE] [--observed FILE]\n  sync [--config FILE] [--apply]    Dry-run only; live writes disabled\n  browser-probe --apply            Read-only browser; private diagnostic capture\n\nCommon: --state-dir DIR (default data/ in the tool folder), --dry-run, --help\nOutput omits queries, addresses, settings, paths, and raw errors.\n`;
async function main() {
  const { positionals, values } = parseArgs({
    allowPositionals: true,
    options: {
      "from-takeout": { type: "string" },
      "state-dir": { type: "string" },
      config: { type: "string" },
      observed: { type: "string" },
      approve: { type: "string" },
      all: { type: "boolean" },
      apply: { type: "boolean" },
      "dry-run": { type: "boolean" },
      help: { type: "boolean" },
    },
  });
  if (values.apply && values["dry-run"])
    throw new Error("Choose --apply or --dry-run");
  const [command, ...extra] = positionals;
  if (extra.length) throw new Error("Unexpected positional arguments");
  if (values.help || !command) {
    console.log(HELP);
    return;
  }
  const root = resolve(
    values["state-dir"] ?? join(import.meta.dirname, "..", "data"),
  );
  const emit = (data: unknown) => console.log(JSON.stringify(data, null, 2));
  if (command === "import") {
    if (!values["from-takeout"]) throw new Error("--from-takeout is required");
    const result = await inspectTakeout(values["from-takeout"]);
    const old = await loadState(root);
    const changed = values.apply
      ? (await applyImport(root, result)).changed
      : !old?.imports.some((i) => i.digest === result.digest);
    emit({
      command,
      applied: !!values.apply,
      changed,
      subscriptions: result.records.length,
      duplicateGroups: result.duplicates.length,
    });
    return;
  }
  if (command === "browser-probe") {
    if (!values.apply) {
      emit({
        command,
        applied: false,
        requires:
          "--apply to open a browser and save private diagnostic controls; no alert mutations",
      });
      return;
    }
    await probeBrowser(root);
    emit({ command, applied: true, verified: false });
    return;
  }
  if (command === "sync" && values.apply) refuseLiveApply();
  const state = await loadState(root);
  if (!state)
    throw new Error("Import an authoritative Takeout file with --apply first");
  switch (command) {
    case "inventory":
      emit({
        source: state.initialSource,
        subscriptions: state.initial.length,
        managed: state.managed.length,
        imports: state.imports.length,
      });
      break;
    case "topics": {
      if (values.apply)
        await withLock(root, async () =>
          writePrivate(
            join(root, "topics.yaml"),
            stringify(candidateConfig(state)),
            true,
          ),
        );
      emit({
        applied: !!values.apply,
        topics: state.initial.length,
        queries: state.initial.length,
        status: "draft",
        containsPrivateData: true,
      });
      break;
    }
    case "adoption-plan":
      emit(adoptionPlan(state));
      break;
    case "adopt": {
      if (!values.all || !values.approve)
        throw new Error(
          "Adoption requires --all and --approve DIGEST from adoption-plan",
        );
      const approve = values.approve;
      if (values.apply)
        await withLock(root, async () => {
          const current = await loadState(root);
          if (!current) throw new Error("State disappeared");
          await saveState(root, adopt(current, approve));
        });
      else adopt(state, approve);
      emit({ applied: !!values.apply, scope: "local-ownership-only" });
      break;
    }
    case "validate":
    case "plan":
    case "sync": {
      const config = await readConfig(
        values.config ?? join(root, "topics.yaml"),
      );
      const desired = resolveConfig(config, state);
      if (command === "validate") {
        emit({ valid: true, queries: desired.length });
        break;
      }
      let observed;
      if (values.observed) {
        try {
          observed = observationSchema.parse(
            JSON.parse(await readFile(values.observed, "utf8")),
          );
        } catch {
          throw new Error("Invalid browser observation (values withheld)");
        }
      }
      emit(reconcile(state, desired, observed));
      break;
    }
    default:
      throw new Error("Unknown command");
  }
}
main().catch((error) => {
  // Only controlled messages are printed. Library errors may contain paths or private data.
  const message = error instanceof Error ? error.message : "";
  const safe =
    /^(Invalid |Unsafe |Takeout |Subscriptions |Import exceeds|Unknown |Active |New active |Choose |Unexpected |--from-takeout |Import an |Adoption requires|Approval does |Ambiguous duplicate |Local state is locked|Cannot read state safely|Snapshot integrity |Live sync is disabled|Authentication required|State disappeared)/;
  console.error(
    JSON.stringify({
      error: safe.test(message)
        ? message
        : "Operation failed; private values withheld",
    }),
  );
  process.exitCode = 1;
});
